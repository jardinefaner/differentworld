import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/slide_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Where a block sits relative to the clock — drives the slide's eyebrow
/// label and tone. `next` is the single soonest upcoming block; everything
/// further out is `later`.
enum SlidePhase { done, now, next, later }

/// One schedule block as a **slide** (docs/VISION.md 2026-06-19) — the block's
/// info (time, title, location, who's leading, time-left) and its actions
/// (attendance / trip tools / log a moment / cast) in a single
/// [SlideBlock]. Framed as a card so it sits inside the in-app deck; the
/// cockpit frames the same primitive full-bleed.
class ScheduleSlide extends ConsumerWidget {
  const ScheduleSlide({
    required this.block,
    required this.activity,
    required this.location,
    required this.phase,
    required this.groupId,
    required this.canEdit,
    required this.canObserve,
    this.onEdit,
    super.key,
  });

  final ScheduleBlock block;
  final Activity? activity;
  final Location? location;
  final SlidePhase phase;
  final String groupId;
  final bool canEdit;
  final bool canObserve;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final start = DateTime.tryParse(block.startAt)?.toLocal();
    final end = DateTime.tryParse(block.endAt)?.toLocal();

    final isField = block.kind == BlockKind.fieldTrip;
    final isBreak = block.kind == BlockKind.breakBlock;
    final isClosed = block.kind == BlockKind.closed;

    final blockTitle = block.title?.trim() ?? '';
    final title = blockTitle.isNotEmpty
        ? blockTitle
        : (activity?.name ??
              (isBreak
                  ? 'Break'
                  : isClosed
                  ? 'Closed'
                  : 'Activity'));

    // Lead name — substitute wins over the planned lead (Pat persona).
    // Null-safe: the slide just drops the "with X" clause when unresolved.
    final leadId = block.leadSubstituteMemberId ?? block.leadMemberId;
    final lead = (leadId == null || leadId.isEmpty)
        ? null
        : ref.watch(memberByIdProvider(leadId)).value;

    // Tone by phase — only the live block keeps the loud primary-container
    // signal; done dims, next/later sit on calm surfaces (one-edge accent
    // on the live slide alone).
    final (Color bg, Color fg, Color? accentEdge) = switch (phase) {
      SlidePhase.now => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        scheme.primary,
      ),
      SlidePhase.next => (
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        null,
      ),
      SlidePhase.done => (
        scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        scheme.onSurfaceVariant,
        null,
      ),
      SlidePhase.later => (scheme.surfaceContainerHigh, scheme.onSurface, null),
    };

    final phaseLabel = switch (phase) {
      SlidePhase.now => 'NOW',
      SlidePhase.next => 'NEXT',
      SlidePhase.done => 'DONE',
      SlidePhase.later => 'LATER',
    };
    final timeRange = (start == null || end == null)
        ? ''
        : '${timeOfDay(start)} – ${timeOfDay(end)}';
    final eyebrow = timeRange.isEmpty ? phaseLabel : '$phaseLabel · $timeRange';

    final bodyLines = <String>[
      if (location != null) location!.name,
      if (lead != null) 'with ${lead.displayName}',
    ];
    if (phase == SlidePhase.now && end != null) {
      final mins = end.difference(DateTime.now()).inMinutes;
      if (mins >= 1) bodyLines.add('$mins min left');
    }
    final body = bodyLines.isEmpty ? null : Text(bodyLines.join('  ·  '));

    final icon = isField
        ? Icons.directions_bus_outlined
        : isBreak
        ? Icons.local_cafe_outlined
        : isClosed
        ? Icons.event_busy_outlined
        : Icons.local_activity_outlined;

    // Primary verb: a field trip is always actionable (trip tools); an
    // on-site block surfaces "take attendance" only while it's live.
    SlideAction? primary;
    if (isField) {
      primary = SlideAction(
        label: 'Trip details',
        icon: Icons.fact_check_outlined,
        onPressed: () => context.push('/trips/${block.id}'),
      );
    } else if (phase == SlidePhase.now && !isBreak && !isClosed) {
      primary = SlideAction(
        label: 'Take attendance',
        icon: Icons.how_to_reg_outlined,
        onPressed: () => context.push('/groups/$groupId/attendance'),
      );
    }

    final actions = <SlideAction>[
      if (canObserve &&
          !isClosed &&
          (phase == SlidePhase.now || phase == SlidePhase.done))
        SlideAction(
          label: 'Log a moment',
          icon: Icons.photo_camera_outlined,
          onPressed: () => context.push('/observations/new?groupId=$groupId'),
        ),
    ];

    // Cast the live moment — project THIS block to the room. The present
    // surface follows the day on its own (it watches the live block), so the
    // TV advances at block boundaries with nobody touching the phone.
    final onCast = (phase == SlidePhase.now && !isClosed)
        ? () => unawaited(
            showCastToRoom(
              context,
              mirrorRoute: '/present-room/$groupId',
              mirrorLabel: 'Show this block on the screen',
              mirrorSubtitle:
                  "Put the live block on the room's TV — it follows the day "
                  'on its own.',
            ),
          )
        : null;

    final tertiary = (canEdit && onEdit != null)
        ? SlideAction(
            label: 'Edit block',
            icon: Icons.edit_outlined,
            onPressed: onEdit!,
          )
        : null;

    return _SlideFrame(
      background: bg,
      accentEdge: accentEdge,
      child: SlideBlock(
        foreground: fg,
        // The primary CTA always uses the brand primary so it pops against
        // any phase tone and keeps a guaranteed-contrast label colour.
        accentBackground: scheme.primary,
        accentForeground: scheme.onPrimary,
        icon: icon,
        eyebrow: eyebrow,
        title: title,
        body: body,
        primary: primary,
        actions: actions,
        tertiary: tertiary,
        onCast: onCast,
      ),
    );
  }
}

/// Card frame for a [ScheduleSlide]. Mirrors the cockpit's `_beatFrame`
/// scroll discipline — `SingleChildScrollView > ConstrainedBox(minHeight) >
/// IntrinsicHeight` — so [SlideBlock]'s `Spacer`s flex to fill the page yet
/// the content stays scrollable at large text scale instead of overflowing.
class _SlideFrame extends StatelessWidget {
  const _SlideFrame({
    required this.background,
    required this.accentEdge,
    required this.child,
  });

  final Color background;
  final Color? accentEdge;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: accentEdge == null
              ? const BoxDecoration()
              : BoxDecoration(
                  border: Border(
                    left: BorderSide(color: accentEdge!, width: 4),
                  ),
                ),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                  child: IntrinsicHeight(child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One cohort's day as a **deck** — each block a swipeable [ScheduleSlide],
/// opening on the live block (else the next upcoming, else the last). The
/// rail across the top shows where you are in the day. Toggle-gated by
/// `scheduleDeckProvider`; the agenda list is the default.
class ScheduleDeck extends ConsumerStatefulWidget {
  const ScheduleDeck({required this.group, required this.date, super.key});

  final Group group;
  final String date;

  @override
  ConsumerState<ScheduleDeck> createState() => _ScheduleDeckState();
}

class _ScheduleDeckState extends ConsumerState<ScheduleDeck> {
  PageController? _controller;
  int _index = 0;
  int _lastCount = -1;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blocksAsync = ref.watch(
      scheduleDayForGroupProvider((groupId: widget.group.id, date: widget.date)),
    );
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    final viewer = ref.watch(viewerProvider);
    final canEdit = viewer.canManageSchedule || viewer.canManageSpace;
    final canObserve = viewer.canObserve;

    return blocksAsync.when(
      loading: () => const LoadingSlot(),
      error: (err, _) => ErrorState(
        title: "Couldn't load this cohort's schedule",
        detail: '$err',
        onRetry: () => ref.invalidate(
          scheduleDayForGroupProvider((
            groupId: widget.group.id,
            date: widget.date,
          )),
        ),
      ),
      data: (blocks) {
        if (blocks.isEmpty) {
          return EmptyState(
            icon: Icons.event_available_outlined,
            title: 'No blocks yet for ${widget.group.name}',
            message:
                'Tap "+ Block" to add the first one. You set the time '
                "range — there's no fixed grid.",
          );
        }

        final isToday = widget.date == todayIsoLocal();
        final now = DateTime.now();
        final phases = _phasesFor(blocks, now: now, isToday: isToday);

        // First open lands on the live block; else the soonest upcoming; else
        // (a past or non-today day) the last block. Re-derived only when the
        // block count changes, so a later rebuild never yanks the page out
        // from under a staffer who has swiped away.
        if (_controller == null || _lastCount != blocks.length) {
          final nowIdx = phases.indexOf(SlidePhase.now);
          final nextIdx = phases.indexOf(SlidePhase.next);
          final initial = (nowIdx >= 0
              ? nowIdx
              : nextIdx >= 0
              ? nextIdx
              : isToday
              ? blocks.length - 1
              : 0).clamp(0, blocks.length - 1);
          _controller?.dispose();
          _controller = PageController(initialPage: initial);
          _index = initial;
          _lastCount = blocks.length;
        }

        return Column(
          children: [
            // Cast the WHOLE day as a deck to the room — the generic present
            // engine, fed the day's blocks as slides.
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: TextButton.icon(
                  onPressed: () => unawaited(
                    presentSlides(
                      context,
                      title: widget.group.name,
                      slides: _daySlides(blocks, phases, activities, locations),
                    ),
                  ),
                  icon: const Icon(Icons.cast, size: 18),
                  label: const Text('Present the day'),
                ),
              ),
            ),
            _DeckRail(
              phases: phases,
              index: _index.clamp(0, blocks.length - 1),
              onTap: (i) => unawaited(
                _controller?.animateToPage(
                      i,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                    ) ??
                    Future<void>.value(),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                // Guard the late callback — a mid-animation PageController can
                // emit onPageChanged after the deck is disposed (fast back).
                onPageChanged: (i) {
                  if (!mounted) return;
                  setState(() => _index = i);
                },
                itemCount: blocks.length,
                itemBuilder: (_, i) {
                  final b = blocks[i];
                  final activity = b.activityId == null
                      ? null
                      : activities
                            .where((a) => a.id == b.activityId)
                            .firstOrNull;
                  final loc = b.locationOverrideId == null
                      ? (activity?.defaultLocationId == null
                            ? null
                            : locations
                                  .where((l) => l.id == activity!.defaultLocationId)
                                  .firstOrNull)
                      : locations
                            .where((l) => l.id == b.locationOverrideId)
                            .firstOrNull;
                  return ScheduleSlide(
                    block: b,
                    activity: activity,
                    location: loc,
                    phase: phases[i],
                    groupId: widget.group.id,
                    canEdit: canEdit,
                    canObserve: canObserve,
                    onEdit: canEdit
                        ? () => _pushBlockEdit(context, widget.group.id, b)
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Assigns each block a [SlidePhase]. Exactly the soonest future block is
  /// `next`; the rest of the future is `later`. A non-today day has no live
  /// clock, so every block reads `later` (neutral tone).
  List<SlidePhase> _phasesFor(
    List<ScheduleBlock> blocks, {
    required DateTime now,
    required bool isToday,
  }) {
    final out = <SlidePhase>[];
    var nextTaken = false;
    for (final b in blocks) {
      if (!isToday) {
        out.add(SlidePhase.later);
        continue;
      }
      final start = DateTime.tryParse(b.startAt)?.toLocal();
      final end = DateTime.tryParse(b.endAt)?.toLocal();
      if (start == null || end == null) {
        out.add(SlidePhase.later);
        continue;
      }
      if (!now.isBefore(start) && now.isBefore(end)) {
        out.add(SlidePhase.now);
      } else if (!end.isAfter(now)) {
        out.add(SlidePhase.done);
      } else if (!nextTaken) {
        out.add(SlidePhase.next);
        nextTaken = true;
      } else {
        out.add(SlidePhase.later);
      }
    }
    return out;
  }

  void _pushBlockEdit(BuildContext context, String groupId, ScheduleBlock b) {
    // Mirrors schedule_screen's `_openBlockSheet` extra shape exactly — the
    // `/schedule/block` route destructures this record.
    unawaited(
      context.push<void>(
        '/schedule/block',
        extra: (
          groupId: groupId,
          defaultStart: DateTime.parse(b.startAt).toLocal(),
          existing: b,
          prefillCurriculumSlug: null,
        ),
      ),
    );
  }
}

/// The day's blocks as a deck of [PresentSlide]s for the generic present
/// engine — eyebrow (phase · time range), title, location, kind icon.
List<PresentSlide> _daySlides(
  List<ScheduleBlock> blocks,
  List<SlidePhase> phases,
  List<Activity> activities,
  List<Location> locations,
) {
  final out = <PresentSlide>[];
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    final activity = b.activityId == null
        ? null
        : activities.where((a) => a.id == b.activityId).firstOrNull;
    final loc = b.locationOverrideId == null
        ? null
        : locations.where((l) => l.id == b.locationOverrideId).firstOrNull;
    final blockTitle = b.title?.trim() ?? '';
    final title = blockTitle.isNotEmpty
        ? blockTitle
        : (activity?.name ??
              (b.kind == BlockKind.breakBlock ? 'Break' : 'Activity'));
    final start = DateTime.tryParse(b.startAt)?.toLocal();
    final end = DateTime.tryParse(b.endAt)?.toLocal();
    final timeRange = (start == null || end == null)
        ? ''
        : '${timeOfDay(start)} – ${timeOfDay(end)}';
    final phaseLabel = switch (phases[i]) {
      SlidePhase.now => 'NOW',
      SlidePhase.next => 'NEXT',
      SlidePhase.done => 'DONE',
      SlidePhase.later => 'LATER',
    };
    out.add(
      PresentSlide(
        eyebrow: timeRange.isEmpty ? phaseLabel : '$phaseLabel · $timeRange',
        title: title,
        subtitle: loc?.name,
        icon: b.kind == BlockKind.fieldTrip
            ? Icons.directions_bus_outlined
            : b.kind == BlockKind.breakBlock
            ? Icons.local_cafe_outlined
            : Icons.local_activity_outlined,
      ),
    );
  }
  return out;
}

/// The day's run-of-show as a thin rail of segments — one per block, coloured
/// by phase, the current page raised. The "where am I in the day" affordance;
/// tap a segment to jump there (swipe is the primary gesture).
class _DeckRail extends StatelessWidget {
  const _DeckRail({
    required this.phases,
    required this.index,
    required this.onTap,
  });

  final List<SlidePhase> phases;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color colorFor(SlidePhase p) => switch (p) {
      SlidePhase.now => scheme.primary,
      SlidePhase.next => scheme.primary.withValues(alpha: 0.45),
      SlidePhase.done => scheme.onSurfaceVariant.withValues(alpha: 0.3),
      SlidePhase.later => scheme.outlineVariant,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < phases.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Semantics(
                button: true,
                label: i == index
                    ? 'Current block ${i + 1} of ${phases.length}'
                    : 'Jump to block ${i + 1} of ${phases.length}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  // A 24dp-tall hit area around the thin bar so the rail is
                  // tappable, not just a sliver.
                  child: SizedBox(
                    height: 24,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: i == index ? 7 : 4,
                        decoration: BoxDecoration(
                          color: colorFor(phases[i]),
                          borderRadius: BorderRadius.circular(4),
                          border: i == index
                              ? Border.all(
                                  color: scheme.onSurface.withValues(
                                    alpha: 0.25,
                                  ),
                                  width: 0.5,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
