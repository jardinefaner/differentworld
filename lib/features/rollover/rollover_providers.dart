import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The period the program is currently in, or null before the first
/// rollover (docs/ROLLOVER.md).
final StreamProvider<Term?> currentTermProvider =
    StreamProvider.autoDispose<Term?>((ref) async* {
      final spaceId = ref.watch(viewerProvider).spaceId;
      if (spaceId == null) {
        yield null;
        return;
      }
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.placementsDao.watchCurrentTerm(spaceId);
    });

/// Past children — the ones a rollover moved on. They keep every record
/// they ever had; this is the door back to it.
final StreamProvider<List<Subject>> alumniProvider =
    StreamProvider.autoDispose<List<Subject>>((ref) async* {
      final spaceId = ref.watch(viewerProvider).spaceId;
      if (spaceId == null) {
        yield const [];
        return;
      }
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.subjectsDao.watchAlumniInSpace(spaceId);
    });

/// One child's whole room history, newest first.
// ignore: specify_nonobvious_property_types
final enrollmentHistoryProvider = StreamProvider.autoDispose
    .family<List<Placement>, String>((ref, subjectId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.placementsDao.watchForSubject(subjectId);
    });
