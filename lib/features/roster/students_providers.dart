import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Stream of students in a specific classroom. Family provider keyed by
/// classroom id so each classroom detail screen has its own live query.
/// Stream of students in a specific classroom. Family provider keyed by
/// classroom id. Uses `async*` so the provider stays in `loading` state
/// until the DB is ready, preventing a false "No students yet" flash.
// ignore: specify_nonobvious_property_types
final classroomStudentsProvider =
    StreamProvider.family<List<Student>, String>(
  (ref, classroomId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchStudentsForClassroom(classroomId);
  },
);

class StudentActions {
  StudentActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> create({
    required String classroomId,
    required String firstName,
    required String lastName,
    String? dob,
    String? allergies,
    String? notes,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final profile = _ref.read(currentProfileProvider).value;
    final programId = profile?.programId;
    if (programId == null) {
      throw StateError('No program selected for the current user.');
    }
    await db.createStudent(
      id: _uuid.v4(),
      programId: programId,
      classroomId: classroomId,
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      allergies: allergies,
      notes: notes,
    );
  }

  Future<void> update({
    required String id,
    String? firstName,
    String? lastName,
    String? dob,
    String? allergies,
    String? notes,
    String? classroomId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.updateStudent(
      id: id,
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      allergies: allergies,
      notes: notes,
      classroomId: classroomId,
    );
  }
}

final studentActionsProvider = Provider<StudentActions>(StudentActions.new);
