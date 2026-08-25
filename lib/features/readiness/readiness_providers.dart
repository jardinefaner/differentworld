import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/readiness/readiness.dart';
import 'package:differentworld/features/rooms/room_load_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every subject↔guardian link in the space, as a set of subject ids.
final StreamProvider<Set<String>> subjectIdsWithGuardianProvider =
    StreamProvider.autoDispose<Set<String>>((ref) async* {
      final spaceId = ref.watch(viewerProvider).spaceId;
      if (spaceId == null) {
        yield const <String>{};
        return;
      }
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.guardiansDao
          .watchLinksInSpace(spaceId)
          .map((links) => {for (final l in links) l.subjectId});
    });

/// The cohorts that have ever been arranged — so the briefing stops offering
/// a first round once one has happened.
final StreamProvider<Set<String>> arrangedGroupIdsProvider =
    StreamProvider.autoDispose<Set<String>>((ref) async* {
      final spaceId = ref.watch(viewerProvider).spaceId;
      if (spaceId == null) {
        yield const <String>{};
        return;
      }
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db
          .customSelect(
            'SELECT DISTINCT group_id FROM rotation_rounds WHERE space_id = ?',
            variables: [Variable<String>(spaceId)],
            readsFrom: {db.rotationRounds},
          )
          .watch()
          .map((rows) => {for (final r in rows) r.read<String>('group_id')});
    });

/// What today needs. Empty when there is nothing to do — which is the point.
final Provider<List<ReadinessItem>> readinessProvider =
    Provider.autoDispose<List<ReadinessItem>>((ref) {
      final roster = ref.watch(subjectsInSpaceProvider).value;
      if (roster == null) return const [];
      final withGuardian =
          ref.watch(subjectIdsWithGuardianProvider).value ?? const <String>{};
      final groups = ref.watch(groupsProvider).value ?? const <Group>[];
      final arranged =
          ref.watch(arrangedGroupIdsProvider).value ?? const <String>{};
      final defaultAllows =
          ref
              .watch(viewerProvider)
              .space
              ?.caps
              .getBool(
                SpaceCaps.photoDefaultConsent,
                fallback: true,
              ) ??
          true;
      // Ratio / capacity breaches, phrased once here so the card just
      // renders them.
      final breaches = <String, String>{};
      for (final g in groups) {
        final load = ref.watch(roomLoadProvider(g.id));
        if (!load.breached) continue;
        breaches[g.id] = load.overCapacity
            ? 'over the licensed limit of ${load.licensedCapacity}'
            : 'needs ${load.staffShort} more adult'
                  '${load.staffShort == 1 ? '' : 's'} at '
                  '1:${load.ratioChildrenPerAdult}';
      }

      return computeReadiness(
        roster: roster,
        subjectIdsWithGuardian: withGuardian,
        spaceDefaultAllowsPhotos: defaultAllows,
        groups: groups,
        arrangedGroupIds: arranged,
        roomBreaches: breaches,
      );
    });
