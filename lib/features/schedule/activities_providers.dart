import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active (non-archived) activities for the current space. Drives the
/// activities list + the activity picker in the block edit sheet.
final activitiesProvider = StreamProvider<List<Activity>>((ref) {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final db = ref.watch(appDatabaseProvider).value;
  if (spaceId == null || db == null) {
    return Stream<List<Activity>>.value(const []);
  }
  return db.activitiesDao.watchActiveInSpace(spaceId);
});

/// All activities including archived ones — needed when editing a
/// historical schedule block that points at an archived activity.
final allActivitiesProvider = StreamProvider<List<Activity>>((ref) {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final db = ref.watch(appDatabaseProvider).value;
  if (spaceId == null || db == null) {
    return Stream<List<Activity>>.value(const []);
  }
  return db.activitiesDao.watchAllInSpace(spaceId);
});

/// A single activity, watched live. Used by the activity edit screen.
// ignore: specify_nonobvious_property_types
final activityByIdProvider = StreamProvider.autoDispose
    .family<Activity?, String>((ref, id) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.activitiesDao.watchById(id);
    });

class ActivityActions {
  ActivityActions(this._ref);
  final Ref _ref;

  Future<String> create({
    required String name,
    String? ownerMemberId,
    String? description,
    String? defaultLocationId,
    int? defaultDurationMinutes,
    String? supplies,
    int? ageMin,
    int? ageMax,
    int? maxCapacity,
    bool isOutdoor = false,
    String? indoorAltActivityId,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'create an activity');
    final db = await _ref.read(appDatabaseProvider.future);
    return db.activitiesDao.create(
      spaceId: spaceId,
      name: name,
      // Default owner is the creating member when none specified —
      // matches the "activities own themselves through the staff
      // member who runs them" intent.
      ownerMemberId: ownerMemberId ?? viewer.memberId,
      description: description,
      defaultLocationId: defaultLocationId,
      defaultDurationMinutes: defaultDurationMinutes,
      supplies: supplies,
      ageMin: ageMin,
      ageMax: ageMax,
      maxCapacity: maxCapacity,
      isOutdoor: isOutdoor,
      indoorAltActivityId: indoorAltActivityId,
    );
  }

  Future<void> update_({
    required String id,
    String? name,
    String? description,
    String? ownerMemberId,
    String? defaultLocationId,
    int? defaultDurationMinutes,
    String? supplies,
    int? ageMin,
    int? ageMax,
    int? maxCapacity,
    bool? isOutdoor,
    String? indoorAltActivityId,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.activitiesDao.update_(
      id: id,
      name: name,
      description: description,
      ownerMemberId: ownerMemberId,
      defaultLocationId: defaultLocationId,
      defaultDurationMinutes: defaultDurationMinutes,
      supplies: supplies,
      ageMin: ageMin,
      ageMax: ageMax,
      maxCapacity: maxCapacity,
      isOutdoor: isOutdoor,
      indoorAltActivityId: indoorAltActivityId,
    );
  }

  Future<void> archive(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.activitiesDao.archive(id);
  }

  Future<void> unarchive(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.activitiesDao.unarchive(id);
  }

  /// Tag an activity with Action Words verbs + senses (stored in the
  /// activity's capabilities JSON — no migration). Drives the verb→activity
  /// matcher and the sensory facet. One write so the two keys can't clobber
  /// each other.
  Future<void> setActivityTags(
    Activity activity, {
    required List<String> verbs,
    required List<String> senses,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final caps = Capabilities.fromJson(activity.capabilities)
        .setting(ActivityCaps.actionVerbs, verbs)
        .setting(ActivityCaps.senses, senses);
    await db.activitiesDao.update_(
      id: activity.id,
      capabilitiesJson: caps.toJson(),
    );
  }

  /// Choose (or clear) the full-screen RUNNER a scheduled block launches
  /// for this activity via its "Run" button, instead of the generic `/arc`
  /// teaching arc. Pass a runner slug (see activity_runtime/activity_runners.dart)
  /// or null to clear back to the default arc.
  ///
  /// A single-string-cap read-modify-write that preserves the activity's
  /// other caps (verbs / senses). Pass [currentCapabilities] (the activity's
  /// existing `capabilities` JSON, `null`/`{}` for a fresh row) so the merge
  /// keeps those sibling keys. Optimistic: the local write commits in one
  /// frame; PowerSync syncs later.
  Future<void> setRunnerSlug(
    String activityId,
    String? slug, {
    String? currentCapabilities,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final caps = Capabilities.fromJson(currentCapabilities).setting(
      ActivityCaps.runnerSlug,
      (slug == null || slug.isEmpty) ? null : slug,
    );
    await db.activitiesDao.update_(
      id: activityId,
      capabilitiesJson: caps.toJson(),
    );
  }

  /// Create an activity already tagged with verbs + senses — the
  /// add-custom path from the Action Words activity library.
  Future<String> createTagged({
    required String name,
    required List<String> verbs,
    required List<String> senses,
    String? description,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'create an activity');
    final db = await _ref.read(appDatabaseProvider.future);
    final caps = Capabilities.fromJson('{}')
        .setting(ActivityCaps.actionVerbs, verbs)
        .setting(ActivityCaps.senses, senses);
    return db.activitiesDao.create(
      spaceId: spaceId,
      name: name,
      ownerMemberId: viewer.memberId,
      description: description,
      capabilitiesJson: caps.toJson(),
    );
  }
}

final activityActionsProvider = Provider<ActivityActions>(ActivityActions.new);

/// The ordered routine steps authored on an activity, watched live off its
/// `capabilities` JSON (key [ActivityCaps.routine]). Empty when the activity
/// has no routine. Drives both the authoring editor's seed and the block run
/// sheet's "The routine" section.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final routineForActivityProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, activityId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      await for (final a in db.activitiesDao.watchById(activityId)) {
        if (a == null) {
          yield const <String>[];
        } else {
          yield Capabilities.fromJson(
            a.capabilities,
          ).getStringList(ActivityCaps.routine);
        }
      }
    });

/// Edits to an activity's routine (the ordered step list on its caps JSON).
///
/// Every mutation is a read-modify-write of the SAME `capabilities` cell, so
/// two racing edits (a drag-reorder's `unawaited` write overlapping a delete
/// tap) would both read the same pre-write state and the second `_save` would
/// silently clobber the first. Chaining through [_pending] serializes them —
/// the exact pattern `DayTemplateActions` uses (CLAUDE.md "A list stored in
/// caps JSON needs a serialized read-modify-write"). Held as a stable
/// singleton ([routineActionsProvider]) so `_pending` persists across calls.
///
/// Optimistic + offline-first like every other write: the local Drift write
/// commits in one frame; PowerSync uploads later.
class RoutineActions {
  RoutineActions(this._ref);
  final Ref _ref;

  Future<List<String>> _load(String activityId) async {
    final db = await _ref.read(appDatabaseProvider.future);
    final a = await db.activitiesDao.findById(activityId);
    if (a == null) return const [];
    return Capabilities.fromJson(
      a.capabilities,
    ).getStringList(ActivityCaps.routine);
  }

  Future<void> _save(String activityId, List<String> steps) async {
    final db = await _ref.read(appDatabaseProvider.future);
    // Re-read the row's CURRENT caps inside the serialized op so the routine
    // write merges over its sibling keys (verbs / senses / runner_slug)
    // instead of clobbering them, even if another surface edited those.
    final a = await db.activitiesDao.findById(activityId);
    final caps = Capabilities.fromJson(a?.capabilities).setting(
      ActivityCaps.routine,
      // Drop empties / whitespace-only steps so a stray blank line never
      // persists; store `null` (removes the key) when nothing's left.
      steps.where((s) => s.trim().isNotEmpty).isEmpty
          ? null
          : [
              for (final s in steps) s.trim(),
            ].where((s) => s.isNotEmpty).toList(),
    );
    await db.activitiesDao.update_(
      id: activityId,
      capabilitiesJson: caps.toJson(),
    );
  }

  // Serialize every read-modify-write so concurrent edits apply in order.
  Future<void> _pending = Future<void>.value();

  Future<void> _mutate(
    String activityId,
    List<String> Function(List<String> steps) update,
  ) {
    final op = _pending.then((_) async {
      final steps = await _load(activityId);
      await _save(activityId, update(List<String>.of(steps)));
    });
    // The queue's tail must never be a rejected future, or one failed write
    // would block every later mutation. Callers still see this op's own error.
    _pending = op.catchError((Object _) {});
    return op;
  }

  /// Append a step to the end of the routine.
  Future<void> addStep(String activityId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return Future<void>.value();
    return _mutate(activityId, (steps) => [...steps, trimmed]);
  }

  /// Replace the step at [index] with [text]. Out-of-range indices are a
  /// no-op (a stale tap after the list shrank).
  Future<void> updateStep(String activityId, int index, String text) {
    final trimmed = text.trim();
    return _mutate(activityId, (steps) {
      if (index < 0 || index >= steps.length) return steps;
      if (trimmed.isEmpty) {
        // An emptied step is a delete — keeps the editor honest.
        return [
          for (var i = 0; i < steps.length; i++)
            if (i != index) steps[i],
        ];
      }
      steps[index] = trimmed;
      return steps;
    });
  }

  /// Remove the step at [index].
  Future<void> removeStep(String activityId, int index) {
    return _mutate(activityId, (steps) {
      if (index < 0 || index >= steps.length) return steps;
      return [
        for (var i = 0; i < steps.length; i++)
          if (i != index) steps[i],
      ];
    });
  }

  /// Reorder a step from [oldIndex] to [newIndex]. Matches
  /// `ReorderableListView`'s post-removal-adjusted `newIndex`.
  Future<void> reorder(String activityId, int oldIndex, int newIndex) {
    return _mutate(activityId, (steps) {
      if (oldIndex < 0 || oldIndex >= steps.length) return steps;
      var target = newIndex;
      if (target > oldIndex) target -= 1;
      target = target.clamp(0, steps.length - 1);
      final moved = steps.removeAt(oldIndex);
      steps.insert(target, moved);
      return steps;
    });
  }
}

final routineActionsProvider = Provider<RoutineActions>(RoutineActions.new);

/// Tiny helper so call sites that already hold an [Activity] (the run sheet,
/// the block tile) can read its routine without a provider round-trip. The
/// live [routineForActivityProvider] is the canonical watch; this is the
/// synchronous read off a row already in hand.
List<String> routineOf(Activity activity) => Capabilities.fromJson(
  activity.capabilities,
).getStringList(ActivityCaps.routine);
