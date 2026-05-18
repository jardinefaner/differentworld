import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Stream of Subjects in a specific Group. Family provider keyed by
/// group id. Uses `async*` so the provider stays in `loading` until the
/// DB is ready.
// ignore: specify_nonobvious_property_types
final subjectsInGroupProvider =
    StreamProvider.family<List<Subject>, String>(
  (ref, groupId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchSubjectsInGroup(groupId);
  },
);

class SubjectActions {
  SubjectActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> create({
    required String groupId,
    required String firstName,
    required String lastName,
    String? dob,
    String? allergies,
    String? notes,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final member = _ref.read(currentMemberProvider).value;
    final spaceId = member?.spaceId;
    if (spaceId == null) {
      throw StateError('No Space selected for the current Member.');
    }
    await db.createSubject(
      id: _uuid.v4(),
      spaceId: spaceId,
      groupId: groupId,
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
    String? groupId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.updateSubject(
      id: id,
      firstName: firstName,
      lastName: lastName,
      dob: dob,
      allergies: allergies,
      notes: notes,
      groupId: groupId,
    );
  }

  Future<void> delete(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.deleteSubject(id);
  }
}

final subjectActionsProvider = Provider<SubjectActions>(SubjectActions.new);
