import 'dart:convert';

import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/activity_runtime/roles.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// A role card the teacher added to today's Do board — an
/// `entries.kind='role'` row, active until the room has been it.
class ActiveRole {
  const ActiveRole({
    required this.entryId,
    required this.name,
    required this.emoji,
    required this.done,
  });

  final String entryId;
  final String name;
  final String emoji;
  final bool done;
}

/// Today's roles on the board (active + done), newest first.
final activeRolesTodayProvider = StreamProvider<List<ActiveRole>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) {
    yield const [];
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.entriesDao
      .watchInSpace(spaceId: spaceId, kind: EntryKind.role)
      .map((entries) {
    final today = todayKey();
    final out = <ActiveRole>[];
    for (final e in entries) {
      final local = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (local == null || dateKey(local) != today) continue;
      Map<String, dynamic> d;
      try {
        final decoded = jsonDecode(e.details);
        d = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } on FormatException {
        d = <String, dynamic>{};
      }
      out.add(ActiveRole(
        entryId: e.id,
        name: (d['role_name'] as String?) ?? 'Role',
        emoji: (d['emoji'] as String?) ?? '🎭',
        done: d['done'] == true,
      ));
    }
    return out;
  });
});

class RoleBoardActions {
  RoleBoardActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  /// Add a role-card to today's board. No-op if that role is already on
  /// today's board and not yet done (don't pile up duplicates).
  Future<void> addRole(RoleCard role) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    final memberId = viewer.memberId;
    if (spaceId == null || memberId == null) return;
    final existing = _ref.read(activeRolesTodayProvider).value ?? const [];
    if (existing.any((r) => !r.done && r.name == role.name)) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.create(
      id: _uuid.v4(),
      spaceId: spaceId,
      kind: EntryKind.role,
      recordedBy: memberId,
      detailsJson: jsonEncode(<String, dynamic>{
        'role_name': role.name,
        'emoji': role.emoji,
        'done': false,
      }),
    );
  }

  Future<void> setDone(ActiveRole role, {required bool done}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.updateDetails(
      id: role.entryId,
      detailsJson: jsonEncode(<String, dynamic>{
        'role_name': role.name,
        'emoji': role.emoji,
        'done': done,
      }),
    );
  }

  /// Take a role off the board entirely (deletes the row).
  Future<void> remove(ActiveRole role) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.deleteById(role.entryId);
  }
}

final roleBoardActionsProvider =
    Provider<RoleBoardActions>(RoleBoardActions.new);
