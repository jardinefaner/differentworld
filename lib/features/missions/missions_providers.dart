import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart'
    show EntryKind;
import 'package:differentworld/features/missions/mission_progress.dart';
import 'package:differentworld/features/missions/mission_templates.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// The program's mission catalog (docs/MISSIONS.md). Live so the browse
/// list — and (slice 2) the kid's "take a mission" surface — react to
/// edits. Local-first via Drift; PowerSync syncs space-scoped.
final missionsProvider = StreamProvider<List<Mission>>((ref) {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final db = ref.watch(appDatabaseProvider).value;
  if (spaceId == null || db == null) {
    return Stream<List<Mission>>.value(const []);
  }
  return db.missionsDao.watchInSpace(spaceId);
});

/// Mission completions (the save-progress record) — `entries` of kind
/// 'mission' across the space, newest first. Drives the "done N times"
/// track record on the catalog.
final missionCompletionsProvider = StreamProvider<List<Entry>>((ref) {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final db = ref.watch(appDatabaseProvider).value;
  if (spaceId == null || db == null) {
    return Stream<List<Entry>>.value(const []);
  }
  return db.entriesDao.watchInSpace(spaceId: spaceId, kind: EntryKind.mission);
});

const _uuid = Uuid();

class MissionActions {
  MissionActions(this._ref);
  final Ref _ref;

  Future<String> create({
    required String name,
    String? icon,
    String? tagline,
    String? why,
    String? builds,
    String? rules,
    List<String> actions = const [],
    MissionEvidenceKind evidence = MissionEvidenceKind.check,
    int? minAge,
    int? maxAge,
    int sort = 0,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'add a mission');
    final db = await _ref.read(appDatabaseProvider.future);
    return db.missionsDao.create(
      spaceId: spaceId,
      name: name,
      icon: icon,
      tagline: tagline,
      why: why,
      builds: builds,
      rules: rules,
      actions: encodeMissionActions(actions),
      evidenceKind: evidence.key,
      minAge: minAge,
      maxAge: maxAge,
      sort: sort,
    );
  }

  Future<void> update_({
    required String id,
    String? name,
    String? icon,
    String? tagline,
    String? why,
    String? builds,
    String? rules,
    List<String>? actions,
    MissionEvidenceKind? evidence,
    int? minAge,
    int? maxAge,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.missionsDao.update_(
      id: id,
      name: name,
      icon: icon,
      tagline: tagline,
      why: why,
      builds: builds,
      rules: rules,
      actions: actions == null ? null : encodeMissionActions(actions),
      evidenceKind: evidence?.key,
      minAge: minAge,
      maxAge: maxAge,
    );
  }

  Future<void> delete_(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.missionsDao.delete_(id);
  }

  /// Re-insert a deleted mission verbatim — the `deleteWithUndo` undo path.
  Future<void> restore(Mission mission) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.missionsDao.restore(mission);
  }

  /// Seed the editable catalog from the shipped starter templates — the
  /// director's one-tap head start. Each row is generated fresh (uuid +
  /// timestamps) and ordered by template position.
  Future<void> addStarterSet() async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'add the starter missions');
    final db = await _ref.read(appDatabaseProvider.future);
    // Idempotency: never double-seed. A fast double-tap (or a re-tap after a
    // slow sync) must not insert 11 duplicate missions — there's no
    // UNIQUE(space_id, name), so dedup has to happen here.
    if (await db.missionsDao.countInSpace(spaceId) > 0) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = <MissionsCompanion>[];
    for (var i = 0; i < missionTemplates.length; i++) {
      final t = missionTemplates[i];
      rows.add(
        MissionsCompanion.insert(
          id: _uuid.v4(),
          spaceId: spaceId,
          name: t.name,
          icon: Value(t.icon),
          tagline: Value(t.tagline),
          why: Value(t.why),
          builds: Value(t.builds),
          rules: Value(t.rules),
          actions: Value(encodeMissionActions(t.actions)),
          evidenceKind: t.evidence.key,
          minAge: Value(t.minAge),
          maxAge: Value(t.maxAge),
          isActive: 1,
          sort: i,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await db.missionsDao.createAll(rows);
  }

  /// Record a mission as DONE — the save-progress write. Lands an `entries`
  /// row (kind 'mission') that feeds the track record + the growth book.
  /// Optionally attributed to a [subjectId] (a kid); otherwise room-level.
  Future<void> complete(
    Mission mission, {
    required int stepsDone,
    required int stepsTotal,
    String? subjectId,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'complete a mission');
    final memberId = viewer.memberId;
    if (memberId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.entriesDao.create(
      id: _uuid.v4(),
      spaceId: spaceId,
      kind: EntryKind.mission,
      recordedBy: memberId,
      subjectId: subjectId,
      detailsJson: encodeMissionCompletion(
        missionId: mission.id,
        missionName: mission.name,
        builds: mission.builds,
        stepsDone: stepsDone,
        stepsTotal: stepsTotal,
      ),
    );
  }
}

final missionActionsProvider = Provider<MissionActions>(MissionActions.new);
