import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Stream of classrooms in the signed-in user's program.
///
/// Stays in `loading` state until the local DB is open — without `async*`,
/// returning a stream synchronously before the DB exists makes the consumer
/// see an empty list and render the "No classrooms yet" empty state.
final classroomsProvider = StreamProvider<List<Classroom>>((ref) async* {
  final profile = ref.watch(currentProfileProvider).value;
  final programId = profile?.programId;
  if (programId == null) return; // stream ends without emitting

  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.watchClassroomsForProgram(programId);
});

/// Mutation surface for classrooms. Hide the database object behind methods
/// that take just the user-meaningful parameters.
class ClassroomActions {
  ClassroomActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> create({
    required String name,
    String? ageRange,
    String? color,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final profile = _ref.read(currentProfileProvider).value;
    final programId = profile?.programId;
    if (programId == null) {
      throw StateError('No program selected for the current user.');
    }
    await db.createClassroom(
      id: _uuid.v4(),
      programId: programId,
      name: name,
      ageRange: ageRange,
      color: color,
    );
  }

  Future<void> update({
    required String id,
    String? name,
    String? ageRange,
    String? color,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.updateClassroom(
      id: id,
      name: name,
      ageRange: ageRange,
      color: color,
    );
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteClassroom(id);
  }
}

/// Long-lived singleton. Intentionally not `autoDispose` — actions hold a
/// `Ref` and are reused for the life of the app. Adding autoDispose would
/// break reads while a transient screen is unmounted.
final classroomActionsProvider = Provider<ClassroomActions>(
  ClassroomActions.new,
);
