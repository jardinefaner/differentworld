import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A child's current Hero: the entry id (for its drawing attachment) + the
/// parsed card data.
typedef HeroForSubject = ({String entryId, HeroCardData data});

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
