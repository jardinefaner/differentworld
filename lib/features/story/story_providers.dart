import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
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
