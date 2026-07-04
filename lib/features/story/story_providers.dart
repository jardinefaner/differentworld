import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

/// Every moment in the program (any kind), scoped to what the viewer can
/// see (director: all; teacher: only their cohorts) — the substrate for
/// the room Story. Same visibility shape as `observationsInSpaceProvider`,
/// but all kinds.
final spaceMomentsProvider = StreamProvider<List<Entry>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final memberId = viewer.memberId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  final entries = db.entriesDao.watchAllInSpace(spaceId: spaceId);
  if (viewer.seesAllClassrooms || memberId == null) {
    yield* entries;
    return;
  }
  final assignments = db.groupMembersDao.watchForMember(memberId);
  yield* Rx.combineLatest2<List<Entry>, List<GroupMember>, List<Entry>>(
    entries,
    assignments,
    (entryList, assigns) {
      final ids = assigns.map((a) => a.groupId).toSet();
      return entryList
          .where((e) => e.groupId == null || ids.contains(e.groupId))
          .toList(growable: false);
    },
  );
});

/// The room's Story beats — [spaceMomentsProvider] (visibility-scoped entries)
/// mapped through `momentsFrom` ONCE per data change and memoized, so the
/// room-story screen doesn't re-`jsonDecode` ≤300 entries inside `build()` on
/// every rebuild. Room-level twin of [momentsForSubjectProvider].
final roomMomentsProvider = Provider<AsyncValue<List<Moment>>>((ref) {
  return ref.watch(spaceMomentsProvider).whenData(momentsFrom);
});

/// A child's Story beats — `momentsFrom` (which `jsonDecode`s every entry's
/// `details`) applied ONCE per data change and memoized here, instead of
/// re-decoding every entry inside each screen's `build()` (the "no
/// computation in build()" rule — a leaf screen still rebuilds on theme /
/// keyboard / parent changes, and decoding N entries each time is wasted
/// work). Both the Story timeline and the play-the-story showcase read this.
///
/// autoDispose + family keyed on `subjectId`; null kind = every kind, which
/// is what the whole story needs. View-specific filtering (the showcase drops
/// logistics beats) stays in each screen — it's cheap (no decode).
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final momentsForSubjectProvider = Provider.autoDispose
    .family<AsyncValue<List<Moment>>, String>(
      (ref, subjectId) {
        final entries = ref.watch(
          entriesForSubjectProvider((subjectId: subjectId, kind: null)),
        );
        // `whenData` maps only the data case, so loading / error pass straight
        // through; the decode reruns only when the entries list actually changes.
        return entries.whenData(momentsFrom);
      },
    );
