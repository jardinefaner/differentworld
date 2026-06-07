import 'package:differentworld/core/capabilities/capabilities.dart';
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
final activityByIdProvider =
    StreamProvider.autoDispose.family<Activity?, String>((ref, id) async* {
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
        .setting('action_verbs', verbs)
        .setting('senses', senses);
    await db.activitiesDao.update_(
      id: activity.id,
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
        .setting('action_verbs', verbs)
        .setting('senses', senses);
    return db.activitiesDao.create(
      spaceId: spaceId,
      name: name,
      ownerMemberId: viewer.memberId,
      description: description,
      capabilitiesJson: caps.toJson(),
    );
  }
}

final activityActionsProvider =
    Provider<ActivityActions>(ActivityActions.new);
