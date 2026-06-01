import 'package:differentworld/core/db/app_database.dart';
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
    required this.startAt,
    required this.endAt,
  });

  final String blockId;
  final String groupId;
  final String title;
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
final liveBlockForGroupProvider =
    Provider.autoDispose.family<LiveBlock?, String>((ref, groupId) {
  ref.watch(_liveTickProvider); // re-evaluate on every 30s tick
  final date = todayIsoLocal();
  final blocks = ref
          .watch(scheduleDayForGroupProvider((groupId: groupId, date: date)))
          .value ??
      const <ScheduleBlock>[];
  final now = DateTime.now();

  final live = blocks.where((b) {
    if (b.status != BlockStatus.planned) return false;
    if (b.kind == BlockKind.breakBlock || b.kind == BlockKind.closed) {
      return false;
    }
    final start = DateTime.tryParse(b.startAt)?.toLocal();
    final end = DateTime.tryParse(b.endAt)?.toLocal();
    if (start == null || end == null) return false;
    return !now.isBefore(start) && now.isBefore(end); // start <= now < end
  }).toList()
    // Most-recently-started first — the deterministic overlap winner.
    ..sort((a, b) => b.startAt.compareTo(a.startAt));

  if (live.isEmpty) return null;
  final b = live.first;

  final activities =
      ref.watch(allActivitiesProvider).value ?? const <Activity>[];
  final activityName = b.activityId == null
      ? null
      : activities.where((a) => a.id == b.activityId).firstOrNull?.name;
  final title = (b.title?.trim().isNotEmpty ?? false)
      ? b.title!.trim()
      : (activityName ?? 'Activity');

  return LiveBlock(
    blockId: b.id,
    groupId: b.groupId,
    title: title,
    startAt: DateTime.parse(b.startAt).toLocal(),
    endAt: DateTime.parse(b.endAt).toLocal(),
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
