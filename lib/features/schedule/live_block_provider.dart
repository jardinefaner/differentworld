import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/activity_runtime/activity_runners.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A schedule block happening RIGHT NOW for a group — the ambient
/// context a counselor never has to assert. Captures made while a block
/// is live tie to it automatically. See docs/LIVE_BLOCK_CONTEXT.md.
class LiveBlock {
  const LiveBlock({
    required this.blockId,
    required this.groupId,
    required this.title,
    required this.kind,
    required this.isOutdoor,
    required this.startAt,
    required this.endAt,
  });

  final String blockId;
  final String groupId;
  final String title;

  /// The block's [BlockKind] (`on_site` / `field_trip` / …). Drives the
  /// contextual lead — a field trip reveals vehicle + trip tools.
  final String kind;

  /// Whether the block's activity is outdoors. Drives the lead's headcount-
  /// first treatment away from the room.
  final bool isOutdoor;

  final DateTime startAt;
  final DateTime endAt;
}

/// Re-evaluates "what's live" every 30s so the strip advances at block
/// boundaries with no user action. Emits immediately, then on a timer.
// ignore: specify_nonobvious_property_types
final _liveTickProvider = StreamProvider.autoDispose<int>((ref) async* {
  yield 0;
  yield* Stream<int>.periodic(const Duration(seconds: 30), (i) => i + 1);
});

/// The block live RIGHT NOW for `groupId`, or null. Half-open
/// `[start, end)`; `status == planned`; `kind ∉ {break, closed}`. Overlap
/// resolved by **most-recently-started** (per the rules in
/// docs/LIVE_BLOCK_CONTEXT.md §2).
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final liveBlockForGroupProvider = Provider.autoDispose.family<LiveBlock?, String>((
  ref,
  groupId,
) {
  ref.watch(_liveTickProvider); // re-evaluate on every 30s tick
  final date = todayIsoLocal();
  final blocks =
      ref
          .watch(scheduleDayForGroupProvider((groupId: groupId, date: date)))
          .value ??
      const <ScheduleBlock>[];
  final now = DateTime.now();

  final live =
      blocks.where((b) {
          // status is nullable (older rows predate the column / it's set lazily);
          // a NULL status means a normal planned block, so coalesce.
          if ((b.status ?? BlockStatus.planned) != BlockStatus.planned) {
            return false;
          }
          if (b.kind == BlockKind.breakBlock || b.kind == BlockKind.closed) {
            return false;
          }
          final start = DateTime.tryParse(b.startAt)?.toLocal();
          final end = DateTime.tryParse(b.endAt)?.toLocal();
          if (start == null || end == null) return false;
          return !now.isBefore(start) &&
              now.isBefore(end); // start <= now < end
        }).toList()
        // Most-recently-started first — the deterministic overlap winner.
        ..sort((a, b) => b.startAt.compareTo(a.startAt));

  if (live.isEmpty) return null;
  final b = live.first;

  final activities =
      ref.watch(allActivitiesProvider).value ?? const <Activity>[];
  final activity = b.activityId == null
      ? null
      : activities.where((a) => a.id == b.activityId).firstOrNull;
  final title = (b.title?.trim().isNotEmpty ?? false)
      ? b.title!.trim()
      : (activity?.name ?? 'Activity');

  return LiveBlock(
    blockId: b.id,
    groupId: b.groupId,
    title: title,
    kind: b.kind,
    isOutdoor: (activity?.isOutdoor ?? 0) == 1,
    startAt: DateTime.parse(b.startAt).toLocal(),
    endAt: DateTime.parse(b.endAt).toLocal(),
  );
});

/// The cohort's NEXT planned block after now — the "what's next" a teacher
/// gets handed when they finish running the current block, instead of being
/// dropped on a dead clock. Earliest `planned`, `kind ∉ {break, closed}`
/// block whose `startAt` is strictly after now (so the one running now never
/// re-suggests itself). Carries enough to LAUNCH the next run the exact way
/// the schedule's "Run" button does — the runner slug (if the activity names
/// one) and the topic for the generic `/arc`.
class NextBlock {
  const NextBlock({
    required this.blockId,
    required this.groupId,
    required this.title,
    required this.startAt,
    required this.runnerSlug,
    required this.runTopic,
  });

  final String blockId;
  final String groupId;
  final String title;
  final DateTime startAt;

  /// The activity's chosen full-screen runner slug, or null → launch the
  /// generic teaching arc (`/arc`). Resolved against [kActivityRunners] by
  /// the caller via [runnerForSlug].
  final String? runnerSlug;

  /// What to present — the activity's name, else the block title. Feeds
  /// `/arc`'s topic and a runner's `?prompt=`.
  final String runTopic;
}

/// The cohort `groupId`'s next planned block strictly after now, or null when
/// nothing is left on the day. Same local-first read + 30s re-evaluation as
/// [liveBlockForGroupProvider]; only the predicate differs (future, not live).
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final nextScheduledBlockProvider = Provider.autoDispose
    .family<NextBlock?, String>((ref, groupId) {
      ref.watch(_liveTickProvider); // re-evaluate on every 30s tick
      final date = todayIsoLocal();
      final blocks =
          ref
              .watch(
                scheduleDayForGroupProvider((groupId: groupId, date: date)),
              )
              .value ??
          const <ScheduleBlock>[];
      final now = DateTime.now();

      final upcoming =
          blocks.where((b) {
              if ((b.status ?? BlockStatus.planned) != BlockStatus.planned) {
                return false;
              }
              if (b.kind == BlockKind.breakBlock ||
                  b.kind == BlockKind.closed) {
                return false;
              }
              final start = DateTime.tryParse(b.startAt)?.toLocal();
              if (start == null) return false;
              return start.isAfter(now); // strictly future
            }).toList()
            // Earliest-starting first — the next thing on the day.
            ..sort((a, b) => a.startAt.compareTo(b.startAt));

      if (upcoming.isEmpty) return null;
      final b = upcoming.first;

      final activities =
          ref.watch(allActivitiesProvider).value ?? const <Activity>[];
      final activity = b.activityId == null
          ? null
          : activities.where((a) => a.id == b.activityId).firstOrNull;
      final title = (b.title?.trim().isNotEmpty ?? false)
          ? b.title!.trim()
          : (activity?.name ?? 'Activity');

      // Mirror _BlockTile's launch resolution: an activity-named runner wins;
      // the topic is the activity name, else the resolved title.
      final runnerSlug = activity == null
          ? null
          : Capabilities.fromJson(
              activity.capabilities,
            ).getString(ActivityCaps.runnerSlug);
      final runTopic = (activity?.name.trim().isNotEmpty ?? false)
          ? activity!.name.trim()
          : title;

      return NextBlock(
        blockId: b.id,
        groupId: b.groupId,
        title: title,
        startAt: DateTime.parse(b.startAt).toLocal(),
        runnerSlug: runnerSlug,
        runTopic: runTopic,
      );
    });

/// The block live across the viewer's visible groups — drives the live
/// strip on the omnibox bar. `groupsProvider` is already scoped to the
/// viewer's assigned rooms (director sees all), so this is "live across
/// MY rooms". If several rooms have a live block, most-recently-started
/// wins.
// ignore: specify_nonobvious_property_types
final liveBlockProvider = Provider.autoDispose<LiveBlock?>((ref) {
  final groups = ref.watch(groupsProvider).value ?? const <Group>[];
  final lives = <LiveBlock>[];
  for (final g in groups) {
    final live = ref.watch(liveBlockForGroupProvider(g.id));
    if (live != null) lives.add(live);
  }
  if (lives.isEmpty) return null;
  lives.sort((a, b) => b.startAt.compareTo(a.startAt));
  return lives.first;
});
