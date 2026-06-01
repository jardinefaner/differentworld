import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
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

  /// Seed the editable catalog from the shipped starter templates — the
  /// director's one-tap head start. Each row is generated fresh (uuid +
  /// timestamps) and ordered by template position.
  Future<void> addStarterSet() async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'add the starter missions');
    final db = await _ref.read(appDatabaseProvider.future);
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
}

final missionActionsProvider = Provider<MissionActions>(MissionActions.new);
