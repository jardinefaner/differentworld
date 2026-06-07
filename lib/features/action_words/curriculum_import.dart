import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seeds the curriculum's ~75 activities into the program's activity library
/// — each tagged with its world's featured verbs so it shows up in the
/// verb→activity matcher and can drop into a day-template. IDEMPOTENT: each
/// imported row carries a `curriculum_key` marker (`worldId:index`) in its
/// caps, so re-running only adds what's missing (e.g. after the catalog
/// grows). Activities are a synced table, so this is real per-program data —
/// it's a director action, not an auto-seed.
class CurriculumImporter {
  CurriculumImporter(this._ref);
  final Ref _ref;

  static const _keyMarker = 'curriculum_key';
  static const _worldMarker = 'curriculum_world';

  /// Import the missing curriculum activities. Returns how many were added.
  Future<int> importActivities() async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) return 0;

    final worlds = await _ref.read(curriculumWorldsProvider.future);
    final db = await _ref.read(appDatabaseProvider.future);
    final existing = await db.activitiesDao.watchAllInSpace(spaceId).first;

    final importedKeys = <String>{};
    for (final a in existing) {
      final k = Capabilities.fromJson(a.capabilities).getString(_keyMarker);
      if (k != null && k.isNotEmpty) importedKeys.add(k);
    }

    var created = 0;
    await db.transaction(() async {
      for (final w in worlds) {
        for (var i = 0; i < w.activities.length; i++) {
          final key = '${w.id}:$i';
          if (importedKeys.contains(key)) continue;
          final activity = w.activities[i];
          final caps = Capabilities.fromJson('{}')
              .setting('action_verbs', w.featuredVerbs)
              .setting('senses', const <String>[])
              .setting(_keyMarker, key)
              .setting(_worldMarker, w.id);
          await db.activitiesDao.create(
            spaceId: spaceId,
            name: curriculumActivityName(activity),
            description: activity,
            ownerMemberId: viewer.memberId,
            isOutdoor: curriculumActivityIsOutdoor(activity),
            capabilitiesJson: caps.toJson(),
          );
          created++;
        }
      }
    });
    return created;
  }

  /// How many curriculum activities have NOT yet been imported (drives the
  /// button label / whether to offer the import at all).
  Future<int> pendingCount() async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) return 0;
    final worlds = await _ref.read(curriculumWorldsProvider.future);
    final total = worlds.fold<int>(0, (sum, w) => sum + w.activities.length);
    final db = await _ref.read(appDatabaseProvider.future);
    final existing = await db.activitiesDao.watchAllInSpace(spaceId).first;
    final imported = existing
        .where((a) =>
            (Capabilities.fromJson(a.capabilities).getString(_keyMarker) ?? '')
                .isNotEmpty)
        .length;
    return (total - imported).clamp(0, total);
  }

}

final curriculumImporterProvider =
    Provider<CurriculumImporter>(CurriculumImporter.new);

/// The activity title — the part before the first colon ("Body map"),
/// trimmed to a sane length; the full prompt becomes the description.
String curriculumActivityName(String activity) {
  final idx = activity.indexOf(':');
  final raw = (idx > 0 ? activity.substring(0, idx) : activity).trim();
  return raw.length > 48 ? '${raw.substring(0, 45)}…' : raw;
}

bool curriculumActivityIsOutdoor(String s) {
  final t = s.toLowerCase();
  return t.contains('outside') ||
      t.contains('outdoor') ||
      t.contains('the yard') ||
      t.contains('go outside');
}
