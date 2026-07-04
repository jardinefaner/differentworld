import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A child's current Hero: the entry id (for its drawing attachment) + the
/// parsed card data.
typedef HeroForSubject = ({String entryId, HeroCardData data});

/// One card in the deck — the role + which child owns it + the entry id (for
/// the drawing). Used by the deck game.
typedef DeckCard = ({String subjectId, String entryId, HeroCardData data});

/// Every role card in the program — the deck. Drives the role game (needs all
/// cards at once to draw a pair). Drift-watched, offline-first.
final heroesInSpaceProvider = StreamProvider<List<DeckCard>>((ref) async* {
  final spaceId = ref.watch(viewerProvider).spaceId;
  if (spaceId == null) {
    yield const <DeckCard>[];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.entriesDao.watchInSpace(spaceId: spaceId, kind: EntryKind.hero).map(
    (rows) {
      final out = <DeckCard>[];
      for (final e in rows) {
        final sid = e.subjectId;
        final data = HeroCardData.tryParse(e.details);
        if (sid != null && data != null) {
          out.add((subjectId: sid, entryId: e.id, data: data));
        }
      }
      return out;
    },
  );
});

/// The child's current Hero (docs/VISION.md 2026-06-19), parsed from their
/// latest `hero` entry. `null` until they've made one. `recordHero` upserts a
/// single evolving row per child, so this is the *current* hero — not a
/// history. Drift-watched, so it's offline-first and live.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final heroForSubjectProvider = StreamProvider.autoDispose
    .family<HeroForSubject?, String>((
      ref,
      subjectId,
    ) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.entriesDao
          .watchForSubject(
            subjectId: subjectId,
            kind: EntryKind.hero,
            limit: 1,
          )
          .map((rows) {
            if (rows.isEmpty) return null;
            final row = rows.first;
            final data = HeroCardData.tryParse(row.details);
            if (data == null) return null;
            return (entryId: row.id, data: data);
          });
    });
