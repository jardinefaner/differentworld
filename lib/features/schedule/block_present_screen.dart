import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Full-screen room-facing projection of a cohort's LIVE schedule block — the
/// slide cast to the TV (docs/VISION.md 2026-06-19: *"the app creates slides
/// that coordinate the room"*). Info-only: the block's title, the room, the
/// clock — no staff affordances. It follows the day on its own:
/// [liveBlockForGroupProvider] re-evaluates every 30s, so the projection
/// advances at block boundaries with nobody touching the phone.
///
/// Raw-canvas projection — deliberately dark regardless of OS theme (it lives
/// on a TV / projector); on the theme-adherence allowlist.
class BlockPresentScreen extends ConsumerStatefulWidget {
  const BlockPresentScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<BlockPresentScreen> createState() => _BlockPresentScreenState();
}

class _BlockPresentScreenState extends ConsumerState<BlockPresentScreen> {
  late final CastImmersive _immersive;

  @override
  void initState() {
    super.initState();
    // Cache the notifier (don't touch ref in dispose) — the cast pattern.
    _immersive = ref.read(castImmersiveProvider.notifier);
    // Defer the provider write past this build phase; guard on mounted so a
    // same-frame pop can't leave chrome hidden, and keep the OS immersive
    // call in the same microtask so the two stay in lockstep.
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        _immersive.enter();
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
        );
      }),
    );
  }

  @override
  void dispose() {
    // Deferred: a synchronous provider write here throws "Tried to modify a
    // provider while the widget tree was building" when the screen is torn
    // down during a build/finalize pass — which is what a route pop does.
    // Seen on device 2026-08-24. Safety comes from CastImmersive's depth
    // counter, not from a mounted guard (this must run AFTER dispose).
    final immersive = _immersive;
    unawaited(
      Future.microtask(() {
        immersive.exit();
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
        );
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(liveBlockForGroupProvider(widget.groupId));
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final group = groups.where((g) => g.id == widget.groupId).firstOrNull;
    final roomName = group?.name ?? 'The room';
    // Warm the projection to this week's curriculum world (its emoji + a deep
    // tint of its colour over near-black) when one is running; otherwise stay
    // plain dark. Raw canvas, so the content-driven world colour is allowed.
    final world = ref.watch(currentWorldProvider);
    final bg = world == null
        ? Colors.black
        : Color.alphaBlend(
            world.color.withValues(alpha: 0.30),
            const Color(0xFF0B0B0D),
          );

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: live != null
                    ? _LiveProjection(
                        live: live,
                        roomName: roomName,
                        world: world,
                      )
                    : _BetweenProjection(
                        groupId: widget.groupId,
                        roomName: roomName,
                      ),
              ),
            ),
          ),
          // Explicit exit — immersiveSticky hides the OS back bar, so the
          // staffer holding the device needs a deliberate way out.
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Exit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The live block, big and calm — pulse + LIVE eyebrow, the activity icon,
/// the title, the room, and the clock.
class _LiveProjection extends StatelessWidget {
  const _LiveProjection({
    required this.live,
    required this.roomName,
    required this.world,
  });

  final LiveBlock live;
  final String roomName;
  final CurriculumWorld? world;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minsLeft = live.endAt.difference(DateTime.now()).inMinutes;
    final icon = live.isOutdoor
        ? Icons.wb_sunny_outlined
        : live.kind == BlockKind.fieldTrip
        ? Icons.directions_bus_outlined
        : live.kind == BlockKind.breakBlock
        ? Icons.local_cafe_outlined
        : Icons.local_activity_outlined;
    // Lead with the world's glyph when one is running; else the activity icon.
    final glyph = world != null
        ? Text(world!.emoji, style: const TextStyle(fontSize: 58))
        : Icon(icon, size: 60, color: Colors.white70);
    // Weave the room and (when present) the world into one quiet line.
    final subtitle = world != null ? '$roomName · ${world!.name}' : roomName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LiveDot(),
            const SizedBox(width: 10),
            Text(
              'LIVE',
              style: theme.textTheme.labelLarge?.copyWith(
                color: Colors.white70,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph,
            const SizedBox(height: 22),
            Text(
              live.title,
              style: theme.textTheme.displayLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white60,
              ),
            ),
          ],
        ),
        Text(
          minsLeft >= 1
              ? '${timeOfDay(live.startAt)} – ${timeOfDay(live.endAt)}'
                    '      ·      $minsLeft min left'
              : '${timeOfDay(live.startAt)} – ${timeOfDay(live.endAt)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white60,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// No block is live — show what's next (or that the day has wrapped). Keeps the
/// room's screen calm and informative between blocks.
class _BetweenProjection extends ConsumerWidget {
  const _BetweenProjection({required this.groupId, required this.roomName});

  final String groupId;
  final String roomName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocks =
        ref
            .watch(
              scheduleDayForGroupProvider((
                groupId: groupId,
                date: todayIsoLocal(),
              )),
            )
            .value ??
        const <ScheduleBlock>[];
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final now = DateTime.now();

    ScheduleBlock? next;
    for (final b in blocks) {
      final start = DateTime.tryParse(b.startAt)?.toLocal();
      if (start != null && start.isAfter(now)) {
        next = b;
        break;
      }
    }

    String eyebrow;
    String title;
    String? footer;
    if (next != null) {
      final activity = next.activityId == null
          ? null
          : activities.where((a) => a.id == next!.activityId).firstOrNull;
      final t = (next.title?.trim().isNotEmpty ?? false)
          ? next.title!.trim()
          : (activity?.name ?? 'Next activity');
      final start = DateTime.tryParse(next.startAt)?.toLocal();
      eyebrow = 'UP NEXT';
      title = t;
      footer = start == null ? null : 'at ${timeOfDay(start)}';
    } else if (blocks.isNotEmpty) {
      eyebrow = roomName.toUpperCase();
      title = "That's a wrap on today";
      footer = null;
    } else {
      eyebrow = roomName.toUpperCase();
      title = 'Nothing scheduled';
      footer = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.labelLarge?.copyWith(
            color: Colors.white54,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          title,
          style: theme.textTheme.displayMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            height: 1.05,
          ),
        ),
        Text(
          footer ?? roomName,
          style: theme.textTheme.titleMedium?.copyWith(color: Colors.white54),
        ),
      ],
    );
  }
}

/// A small steady "live" dot. Static (no controller) — the word LIVE carries
/// the state; the dot is just the colour cue.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: Color(0xFF3FD18F),
        shape: BoxShape.circle,
      ),
    );
  }
}
