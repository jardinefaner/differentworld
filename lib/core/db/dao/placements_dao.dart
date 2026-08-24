import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'placements_dao.g.dart';

/// Periods, placements, and the year rollover (docs/ROLLOVER.md).
///
/// A PLACEMENT is one child in one room for one period. It is not called an
/// enrollment because `enrollments` has meant staff↔classroom since the
/// foundation migration.
///
/// The whole point of this DAO is that **nothing it does is destructive**.
/// A new intake used to mean deleting last year's children; here it means
/// closing their enrollment and opening a new one, so a child's record only
/// ever grows.
@DriftAccessor(tables: [Terms, Placements, Subjects])
class PlacementsDao extends DatabaseAccessor<AppDatabase>
    with _$PlacementsDaoMixin {
  PlacementsDao(super.attachedDatabase);

  // ── Periods ────────────────────────────────────────────────────────────

  Stream<List<Term>> watchTerms(String spaceId) {
    return (select(terms)
          ..where((t) => t.spaceId.equals(spaceId))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.startsOn, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<Term?> watchCurrentTerm(String spaceId) {
    return (select(terms)
          ..where((t) => t.spaceId.equals(spaceId) & t.isCurrent.equals(1))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<Term?> currentTerm(String spaceId) {
    return (select(terms)
          ..where((t) => t.spaceId.equals(spaceId) & t.isCurrent.equals(1))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> createTerm(TermsCompanion row) => into(terms).insert(row);

  // ── Enrollments ────────────────────────────────────────────────────────

  /// A child's whole history, newest first — "Ospreys now, Sparrows last
  /// year". This is what the child record shows under Rooms.
  Stream<List<Placement>> watchForSubject(String subjectId) {
    return (select(placements)
          ..where((e) => e.subjectId.equals(subjectId))
          ..orderBy([
            (e) =>
                OrderingTerm(expression: e.startedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<List<Placement>> watchForTerm(String termId) {
    return (select(placements)..where((e) => e.termId.equals(termId))).watch();
  }

  /// Placements with no end date — the current period's.
  Future<List<Placement>> openPlacements(String spaceId) {
    return (select(
      placements,
    )..where((e) => e.spaceId.equals(spaceId) & e.endedAt.isNull())).get();
  }

  Future<void> createPlacement(PlacementsCompanion row) =>
      into(placements).insert(row);

  // ── The rollover ───────────────────────────────────────────────────────

  /// Start a new period, in ONE transaction, deleting nothing.
  ///
  /// For each child: close their open enrollment, then either open a new one
  /// in [returning]'s room (and keep them `enrolled`) or mark them `alumni`.
  /// An alumnus keeps every row they ever had — observations, photo tags,
  /// messages, their character sheet, their book. They simply stop appearing
  /// in attendance, pickers and today's rosters.
  ///
  /// [returning] maps subject id → the room they join (null = enrolled but
  /// unplaced). Any open-enrolled child absent from the map becomes alumni.
  Future<void> applyRollover({
    required String spaceId,
    required TermsCompanion newTerm,
    required String newTermId,
    required Map<String, String?> returning,
    required String Function() newId,
    required String nowIso,
  }) async {
    await transaction(() async {
      // Only one period can be current; clear the old flag first so the
      // partial unique index server-side never sees two.
      await (update(terms)..where((t) => t.spaceId.equals(spaceId))).write(
        const TermsCompanion(isCurrent: Value(0)),
      );
      await into(terms).insert(newTerm);

      final open = await openPlacements(spaceId);
      for (final e in open) {
        await (update(placements)..where((r) => r.id.equals(e.id))).write(
          PlacementsCompanion(
            endedAt: Value(nowIso),
            updatedAt: Value(nowIso),
          ),
        );
      }

      // Everyone currently enrolled — including children who never had an
      // enrollment row because they predate this feature.
      // NULL counts as enrolled — see SubjectsDao.watchInGroup. A row that
      // predates the status column must still be rolled over, or the first
      // rollover after an update quietly skips the entire program.
      final roster =
          await (select(subjects)..where(
                (s) =>
                    s.spaceId.equals(spaceId) &
                    (s.status.equals('enrolled') | s.status.isNull()),
              ))
              .get();

      for (final s in roster) {
        final stays = returning.containsKey(s.id);
        if (stays) {
          final room = returning[s.id];
          await into(placements).insert(
            PlacementsCompanion.insert(
              id: newId(),
              spaceId: spaceId,
              subjectId: s.id,
              termId: newTermId,
              startedAt: nowIso,
              createdAt: nowIso,
              updatedAt: nowIso,
              groupId: Value(room),
            ),
          );
          // Keep the denormalised current room in step, so every existing
          // roster query follows the child up without knowing about terms —
          // and stamp status explicitly, which HEALS the NULL a newly-added
          // column leaves behind. After one rollover the whole roster is
          // self-describing and no query has to be defensive about it.
          final movingRoom = room != null && room != s.groupId;
          if (movingRoom || s.status != 'enrolled') {
            await (update(subjects)..where((r) => r.id.equals(s.id))).write(
              SubjectsCompanion(
                groupId: movingRoom ? Value(room) : const Value.absent(),
                status: const Value('enrolled'),
                updatedAt: Value(nowIso),
              ),
            );
          }
        } else {
          await (update(subjects)..where((r) => r.id.equals(s.id))).write(
            SubjectsCompanion(
              status: const Value('alumni'),
              updatedAt: Value(nowIso),
            ),
          );
        }
      }
    });
  }

  /// Undo a rollover: re-open the placements it closed, drop the ones it
  /// opened, restore everyone it made alumni, and remove the new period.
  /// Reversible because the rollover only ever wrote — it never deleted.
  /// [previousTermId] is null on the very first rollover — there is simply
  /// no earlier period to restore, and undo still has to work.
  Future<void> undoRollover({
    required String spaceId,
    required String termId,
    required String? previousTermId,
    required String nowIso,
  }) async {
    await transaction(() async {
      await (delete(placements)..where((e) => e.termId.equals(termId))).go();
      if (previousTermId != null) {
        await (update(placements)..where(
              (e) =>
                  e.spaceId.equals(spaceId) & e.termId.equals(previousTermId),
            ))
            .write(
              PlacementsCompanion(
                endedAt: const Value(null),
                updatedAt: Value(nowIso),
              ),
            );
      }
      await (update(subjects)..where(
            (s) => s.spaceId.equals(spaceId) & s.status.equals('alumni'),
          ))
          .write(
            SubjectsCompanion(
              status: const Value('enrolled'),
              updatedAt: Value(nowIso),
            ),
          );
      await (delete(terms)..where((t) => t.id.equals(termId))).go();
      if (previousTermId != null) {
        await (update(terms)..where((t) => t.id.equals(previousTermId))).write(
          TermsCompanion(isCurrent: const Value(1), updatedAt: Value(nowIso)),
        );
      }
    });
  }

  /// Bring one alumnus back — a child who returns after a year away.
  Future<void> reinstate(String subjectId, String nowIso) =>
      (update(subjects)..where((s) => s.id.equals(subjectId))).write(
        SubjectsCompanion(
          status: const Value('enrolled'),
          updatedAt: Value(nowIso),
        ),
      );
}
