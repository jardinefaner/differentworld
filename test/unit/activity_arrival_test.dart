// The bespoke activity screens cut too.
//
// The boards have animated since ShapeStageView shipped and the prompt stages
// since GameStage.frame took the decision — both because ONE thing draws them
// all. These eleven share no stage and no layout, so there was nowhere for the
// decision to live, and every one of them that advances a prompt replaced it
// in a single frame.
//
// They share a decision, not a shape. `Arrives` is the decision; this checks
// it reaches the screens that need it, and that the ones which DON'T have
// said why.

import 'dart:io';

import 'package:differentworld/features/activity_runtime/activity_deck.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bespoke deck screens that ADVANCE — tap and a different prompt is there.
const _advances = <String, String>{
  'DoItScreen': 'a new thing to go do',
  'GroupDiscussionScreen': 'the next starter',
  'FillBlankScreen': 'the next blank',
  'MathRunnerScreen': 'the next number',
  'PatternMakerScreen': 'a new pattern to try',
  'RoleCardsScreen': 'a whole different deck of cards',
};

/// Bespoke deck screens that do NOT, each with the reason — because a screen
/// that is deliberately still and one that forgot look identical from outside.
const _still = <String, String>{
  'PhotographyRunnerScreen': 'a camera viewfinder, not a prompt deck',
  'BreatheScreen': 'it IS an animation — a breath, continuously',
  'LettersScreen': 'a board to write on; nothing replaces anything',
  'PennyScreen': 'a growing list — new thoughts join, none replace',
  'PotionsScreen': 'a bench of ingredients the room combines',
  // Not activities at all — instruments, with no prompt to replace.
  'CastScreen': 'the app remote',
  'LiveBoardScreen': 'the phone as a board',
};

void main() {
  test('every screen that advances a prompt lets it ARRIVE', () {
    final missing = <String>[];
    for (final entry in _advances.entries) {
      final source = _sourceOf(entry.key);
      expect(source, isNotNull, reason: '${entry.key} is gone — fix this list');
      if (!source!.contains('Arrives(')) {
        missing.add('${entry.key} (${entry.value})');
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'these replace their prompt in a single frame — wrap the part that '
          'CHANGES (never a TextField, never the whole page) in Arrives: '
          '$missing',
    );
  });

  test('the two lists together cover every bespoke card on the deck', () {
    // The point of the pairing: a NEW activity screen lands in neither list
    // and fails here, so somebody has to decide whether its prompts arrive
    // rather than silently shipping one more that cuts.
    final router = File('lib/app/router.dart').readAsStringSync();
    final known = {..._advances.keys, ..._still.keys};
    final unclassified = <String>[];
    final seen = <String>{};
    for (final card in [...breakDeck(camera: true), ...presentDeck]) {
      if (!seen.add(card.route)) continue;
      // A game — the prompt-stage tests own those.
      if (gameForRoute(card.route) != null) continue;
      final i = router.indexOf("path: '${card.route}'");
      if (i < 0) continue;
      final chunk = router.substring(i, (i + 300).clamp(0, router.length));
      final cls = RegExp(r'\b([A-Z]\w+Screen)\b').firstMatch(chunk)?.group(1);
      if (cls == null) continue;
      if (!known.contains(cls)) unclassified.add(cls);
    }
    expect(
      unclassified,
      isEmpty,
      reason:
          'new activity screens nobody has decided about — add each to '
          '_advances (and wrap its prompt) or to _still with a reason: '
          '$unclassified',
    );
  });
}

/// The file that declares [cls] — found, not guessed. `GroupDiscussionScreen`
/// lives in `discussions_screen.dart`, so deriving a filename from the class
/// name gets at least one wrong and reports it as an unclassified screen.
String? _sourceOf(String cls) {
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final src = f.readAsStringSync();
    if (src.contains('class $cls ')) return src;
  }
  return null;
}
