// Integrity of the Through-My-Eyes session scripts — the 6 runnable beat-decks.
//
// The scripts are hand/agent-authored const data (every say-line verbatim). A
// malformed beat (empty title, a vocab beat with no cards, a content beat with
// nothing to show) compiles + passes `flutter analyze` but renders blank in the
// presenter. This pins the structural invariants the presenter + the cast
// room-view rely on, across all six sessions at once.

import 'package:differentworld/features/curricula/photo_curriculum.dart';
import 'package:differentworld/features/curricula/session_script.dart';
import 'package:differentworld/features/curricula/session_scripts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all six sessions are registered, unique, and resolvable', () {
    expect(allSessionScripts.length, 6);

    final slugs = allSessionScripts.map((s) => s.slug).toSet();
    expect(slugs.length, 6, reason: 'slugs must be unique');

    // Registered in session order (the registry + the wall progression rely on
    // it).
    expect(
      allSessionScripts.map((s) => s.sessionNumber).toList(),
      <int>[1, 2, 3, 4, 5, 6],
    );

    for (final s in allSessionScripts) {
      expect(scriptForSession(s.slug), same(s), reason: '${s.slug} resolves');
      expect(
        findSessionBySlug(s.slug),
        isNotNull,
        reason: '${s.slug} has a PhotoSession summary to badge it',
      );
      expect(s.title.trim(), isNotEmpty, reason: '${s.slug} has a title');
      expect(s.beats, isNotEmpty, reason: '${s.slug} has beats');
    }
  });

  test('every beat is well-formed (nothing the presenter would render blank)',
      () {
    for (final s in allSessionScripts) {
      for (final b in s.beats) {
        final where = '${s.slug} · "${b.title}"';
        expect(b.title.trim(), isNotEmpty, reason: '$where: empty beat title');

        // A vocab beat must carry the words to tape up.
        if (b.kind == BeatKind.vocab) {
          expect(b.vocabCards, isNotEmpty, reason: '$where: vocab beat, no cards');
        }
        // A game beat that carries a BeatGame must name it.
        if (b.game != null) {
          expect(
            b.game!.name.trim(),
            isNotEmpty,
            reason: '$where: BeatGame with no name',
          );
        }
        // Every beat must have SOMETHING for the slide — key lines, the full
        // script, a game, vocab cards, or a call-and-response.
        final hasContent = b.keyLines.isNotEmpty ||
            b.script.isNotEmpty ||
            b.game != null ||
            b.vocabCards.isNotEmpty ||
            (b.callResponse?.trim().isNotEmpty ?? false);
        expect(hasContent, isTrue, reason: '$where: beat has no content');
      }
    }
  });
}
