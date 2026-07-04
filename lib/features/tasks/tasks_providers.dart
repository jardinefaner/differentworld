import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Filter shape for [tasksProvider]. `open` is the daily list;
/// `all` includes done + dismissed and is used by audit / "this
/// week" views.
enum TaskFilter { open, all }

/// All tasks matching the given filter in the signed-in user's
/// space, due-first then oldest open first. Empty when no space.
// ignore: specify_nonobvious_property_types
final tasksProvider = StreamProvider.autoDispose.family<List<Task>, TaskFilter>(
  (ref, filter) async* {
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      yield const <Task>[];
      return;
    }
    final db = await ref.watch(appDatabaseProvider.future);
    yield* switch (filter) {
      TaskFilter.open => db.tasksDao.watchOpen(spaceId),
      TaskFilter.all => db.tasksDao.watchAll(spaceId),
    };
  },
);

/// Open tasks only. Drives the Today launchpad badge + task list.
// ignore: specify_nonobvious_property_types
final openTasksProvider = tasksProvider(TaskFilter.open);

/// All tasks (any status). Audit + "this week" views.
// ignore: specify_nonobvious_property_types
final allTasksProvider = tasksProvider(TaskFilter.all);

/// Tasks attached to a specific kid — surfaces on family / staff
/// per-subject screens.
// ignore: specify_nonobvious_property_types
final tasksForSubjectProvider = StreamProvider.autoDispose
    .family<List<Task>, String>(
      (ref, subjectId) async* {
        final db = await ref.watch(appDatabaseProvider.future);
        yield* db.tasksDao.watchForSubject(subjectId);
      },
    );

/// Status discriminator for the `tasks` table.
class TaskStatus {
  static const String open = 'open';
  static const String completed = 'completed';
}

class TaskActions {
  TaskActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  /// Create a new task. Returns the new id so the caller can navigate
  /// straight to detail / promote audit.
  Future<String> create({
    required String body,
    String? subjectId,
    String? dueAt,
    String? createdFromCaptureId,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'create a task');
    final db = await _ref.read(appDatabaseProvider.future);
    return db.tasksDao.insert(
      id: _uuid.v4(),
      spaceId: spaceId,
      body: body,
      authorId: viewer.memberId,
      subjectId: subjectId,
      dueAt: dueAt,
      createdFromCaptureId: createdFromCaptureId,
    );
  }

  Future<void> updateBody({required String id, required String body}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.tasksDao.updateBody(id: id, body: body);
  }

  /// Bump the due date forward by [days]. If the task had no due date,
  /// snooze sets one for `today + days`. Used by the swipe-right
  /// gesture on the Tasks list — "I'll deal with this tomorrow."
  Future<void> snooze({required String id, int days = 1}) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final base = DateTime.now();
    final next = DateTime(base.year, base.month, base.day + days);
    await db.tasksDao.updateDueAt(
      id: id,
      dueAt: next.toUtc().toIso8601String(),
    );
  }

  /// Mark the task done. Stamps `completed_by` with the current
  /// viewer's memberId so the audit trail is preserved.
  Future<void> markDone(String id) async {
    final viewer = _ref.read(viewerProvider);
    final memberId = viewer.requireMemberId(action: 'complete a task');
    final db = await _ref.read(appDatabaseProvider.future);
    await db.tasksDao.markDone(id: id, completedBy: memberId);
  }

  /// Reopen a done task (mis-tap undo).
  Future<void> reopen(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.tasksDao.reopen(id);
  }

  /// Discard a task — keeps the row for audit, hides it from the list.
  Future<void> discard(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.tasksDao.markDiscarded(id);
  }
}

final taskActionsProvider = Provider<TaskActions>(TaskActions.new);
