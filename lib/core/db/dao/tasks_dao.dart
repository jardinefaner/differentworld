import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'tasks_dao.g.dart';

/// To-do items. Per the framework: the third destination for a
/// captured thought (the first two being an Observation on a kid
/// or a Discard). Tasks can stand alone or live attached to a kid
/// via `subject_id`.
@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase>
    with _$TasksDaoMixin {
  TasksDao(super.attachedDatabase);

  /// Open tasks in a space, due-date first (nulls last), then oldest
  /// open first. Drives the tasks screen and the Today launchpad
  /// count.
  Stream<List<Task>> watchOpen(String spaceId) {
    return (select(tasks)
          ..where((t) => t.spaceId.equals(spaceId) & t.status.equals('open'))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueAt),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  /// All tasks in a space (any status), newest first — for an audit
  /// view / "completed this week" surface.
  Stream<List<Task>> watchAll(String spaceId) {
    return (select(tasks)
          ..where((t) => t.spaceId.equals(spaceId))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .watch();
  }

  /// Tasks attached to a specific kid. Used by the family-side per-
  /// child screen and the staff subject detail.
  Stream<List<Task>> watchForSubject(String subjectId) {
    return (select(tasks)
          ..where((t) => t.subjectId.equals(subjectId))
          ..orderBy([
            (t) => OrderingTerm(expression: t.dueAt),
            (t) => OrderingTerm(expression: t.createdAt),
          ]))
        .watch();
  }

  Future<Task?> findById(String id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<String> insert({
    required String id,
    required String spaceId,
    required String body,
    String? authorId,
    String? subjectId,
    String? dueAt,
    String? createdFromCaptureId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(tasks).insert(
      TasksCompanion.insert(
        id: id,
        spaceId: spaceId,
        authorId: Value(authorId),
        subjectId: Value(subjectId),
        body: body,
        status: 'open',
        dueAt: Value(dueAt),
        createdFromCaptureId: Value(createdFromCaptureId),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> updateBody({
    required String id,
    required String body,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(body: Value(body), updatedAt: Value(now)),
    );
  }

  /// Update the due date for an open task (snooze / reschedule).
  Future<void> updateDueAt({
    required String id,
    required String? dueAt,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(dueAt: Value(dueAt), updatedAt: Value(now)),
    );
  }

  Future<void> markDone({
    required String id,
    required String completedBy,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: const Value('done'),
        completedBy: Value(completedBy),
        completedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Reopen a done task (mistake-undo path).
  Future<void> reopen(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: const Value('open'),
        completedBy: const Value(null),
        completedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markDiscarded(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: const Value('discarded'),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> deleteById(String id) async {
    await (delete(tasks)..where((t) => t.id.equals(id))).go();
  }
}
