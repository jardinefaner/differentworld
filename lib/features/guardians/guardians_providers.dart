import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Guardians linked to a specific subject, ordered with primary
/// guardians first.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final guardiansForSubjectProvider =
    StreamProvider.autoDispose.family<List<Guardian>, String>(
  (ref, subjectId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.guardiansDao.watchForSubject(subjectId);
  },
);

class GuardianActions {
  GuardianActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  Future<void> addToSubject({
    required String subjectId,
    required String name,
    String? relationship,
    String? phone,
    String? email,
    bool isPrimary = false,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final spaceId = _ref.read(currentMemberProvider).value?.spaceId;
    if (spaceId == null) {
      throw StateError('No Space — sign in and join a program first.');
    }
    await db.guardiansDao.createForSubject(
      guardianId: _uuid.v4(),
      subjectId: subjectId,
      spaceId: spaceId,
      name: name,
      relationship: relationship,
      phone: phone,
      email: email,
      isPrimary: isPrimary,
    );
  }

  Future<void> unlink({
    required String guardianId,
    required String subjectId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.guardiansDao.unlinkFromSubject(
      guardianId: guardianId,
      subjectId: subjectId,
    );
  }
}

final guardianActionsProvider =
    Provider<GuardianActions>(GuardianActions.new);
