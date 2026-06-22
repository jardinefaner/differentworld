import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/activity_runtime/activity_runners.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/block_edit_screen.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/supplies/activity_supplies_providers.dart';
import 'package:differentworld/features/supplies/supplies_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Args for the Block Run Sheet route, passed via go_router `extra`.
/// Carries the whole [ScheduleBlock] so the sheet resolves its linked
/// activity → routine + supplies without a second fetch. (The block also
/// carries `groupId`, which the cast action needs.)
typedef BlockRunSheetArgs = ({ScheduleBlock block});

/// `/schedule/block/run` — a block's self-contained run sheet (docs/VISION.md
/// 2026-06-19: *"each block self-contained — all its info AND its actions,
/// together"*). Tapping a content-bearing schedule block opens THIS instead of
/// the edit page.
///
/// Top to bottom: the header (time · location · lead; the activity name; its
/// subtitle/prompt + an Edit pencil) → **The routine** (the activity's ordered
/// numbered steps) → **What you'll need** (the activity's supply pack list as
/// chips) → actions: a primary [Start {activity}] + secondary [Capture] +
/// [Cast to room].
///
/// Offline-first: every read is a Drift watch; nothing awaits the network.
class BlockRunSheetScreen extends ConsumerWidget {
  const BlockRunSheetScreen({required this.block, super.key});

  final ScheduleBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Resolve the linked activity (allActivities so an archived link still
    // resolves its name + routine). The block may be a bare/typed block with
    // no activity — the routine then reads off whatever the block names.
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final activity = block.activityId == null
        ? null
        : activities.where((a) => a.id == block.activityId).firstOrNull;

    // Effective location: the block's override, else the activity default.
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    final effectiveLocationId =
        block.locationOverrideId ?? activity?.defaultLocationId;
    final location = effectiveLocationId == null
        ? null
        : locations.where((l) => l.id == effectiveLocationId).firstOrNull;

    // The lead (planned, or the substitute when one's covering today).
    final members = ref.watch(membersInSpaceProvider).value ?? const <Member>[];
    final leadId = block.leadSubstituteMemberId ?? block.leadMemberId;
    final lead = leadId == null
        ? null
        : members.where((m) => m.id == leadId).firstOrNull;

    // The block's resolved title (same precedence as the agenda tile: the
    // typed title wins, else the activity name, else a kind fallback).
    final blockTitle = block.title?.trim() ?? '';
    final title = blockTitle.isNotEmpty
        ? blockTitle
        : (activity?.name ?? 'This block');

    // The activity's prompt/subtitle (its description) — what staff (and
    // parents on the block) read for "what happens here".
    final subtitle = activity?.description?.trim();

    final start = DateTime.tryParse(block.startAt)?.toLocal();
    final end = DateTime.tryParse(block.endAt)?.toLocal();
    final timeLabel = (start != null && end != null)
        ? '${timeOfDay(start)} – ${timeOfDay(end)}'
        : '';
    // time · location · lead — only the parts we have, joined by a dot.
    final metaParts = <String>[
      if (timeLabel.isNotEmpty) timeLabel,
      if (location != null) location.name,
      if (lead != null) lead.displayName,
    ];

    // The routine — read live off the activity's caps.
    final routine = activity == null
        ? const <String>[]
        : ref.watch(routineForActivityProvider(activity.id)).value ??
              const <String>[];

    // "Run" plumbing — mirrors the agenda tile exactly. The topic is the
    // activity name, else the resolved title; the activity's chosen runner
    // (if any) launches directly, else the generic `/arc` teaching arc.
    final runTopic = (activity?.name.trim().isNotEmpty ?? false)
        ? activity!.name.trim()
        : title.trim();
    final runner = activity == null
        ? null
        : runnerForSlug(
            Capabilities.fromJson(
              activity.capabilities,
            ).getString(ActivityCaps.runnerSlug),
          );
    final startLabel = activity != null
        ? 'Start ${activity.name.trim()}'
        : 'Start';

    return EdgeScaffold(
      backFallbackRoute: '/schedule',
      actions: [
        IconButton(
          tooltip: 'Edit block',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _openEdit(context),
        ),
      ],
      body: FormBody(
        children: [
          ContentHeader(title: title),
          if (metaParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                metaParts.join('  ·  '),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurface,
                height: 1.35,
              ),
            ),
          ],

          // ── The routine ──────────────────────────────────────────────
          const SizedBox(height: 28),
          const _SectionLabel(text: 'The routine'),
          const SizedBox(height: 8),
          if (routine.isEmpty)
            _RoutineEmptyHint(activity: activity)
          else
            for (var i = 0; i < routine.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${i + 1}.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        routine[i],
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

          // ── What you'll need ─────────────────────────────────────────
          const SizedBox(height: 28),
          const _SectionLabel(text: "What you'll need"),
          const SizedBox(height: 8),
          if (activity == null)
            const _NeedsHint(
              text:
                  'Link an activity to this block to pull in its supply list.',
            )
          else
            _SupplyChips(activityId: activity.id),

          // ── Actions ──────────────────────────────────────────────────
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => _start(context, runner: runner, topic: runTopic),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(startLabel),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _capture(context),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Capture'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _cast(context),
            icon: const Icon(Icons.cast),
            label: const Text('Cast to room'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    // Reuse the existing block edit page. Args mirror what the schedule
    // screen's `_openBlockSheet` passes.
    final BlockEditArgs args = (
      groupId: block.groupId,
      defaultStart: DateTime.parse(block.startAt).toLocal(),
      existing: block,
      prefillCurriculumSlug: null,
    );
    unawaited(context.push<void>('/schedule/block', extra: args));
  }

  /// Start the activity — the SAME runner-slug / teaching-arc launch the
  /// agenda tile's "Run" button used (now folded into the run sheet).
  void _start(
    BuildContext context, {
    required ActivityRunner? runner,
    required String topic,
  }) {
    unawaited(HapticFeedback.selectionClick());
    if (runner != null) {
      // Seed the on-screen prompt for runners that accept one (Photo Studio).
      final dest = runner.takesPrompt
          ? Uri(
              path: runner.route,
              queryParameters: {'prompt': topic},
            ).toString()
          : runner.route;
      unawaited(context.push(dest));
    } else {
      unawaited(context.push('/arc', extra: topic));
    }
  }

  void _capture(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(context.push('/captures/new'));
  }

  /// Cast this block to the room — the SAME per-block cast the schedule deck's
  /// slide uses: project the cohort's LIVE block to the TV, which follows the
  /// day on its own.
  void _cast(BuildContext context) {
    unawaited(
      showCastToRoom(
        context,
        mirrorRoute: '/present-room/${block.groupId}',
        mirrorLabel: 'Show this block on the screen',
        mirrorSubtitle:
            "Put the live block on the room's TV — it follows the day on its "
            'own.',
      ),
    );
  }
}

/// Section eyebrow — the calm flush-left label over each run-sheet section.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Gentle hint when the activity has no routine yet, with a link to author it
/// on the activity (never a blank).
class _RoutineEmptyHint extends StatelessWidget {
  const _RoutineEmptyHint({required this.activity});

  final Activity? activity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity == null
              ? 'No routine yet — link an activity to give this block its '
                    'steps.'
              : 'No routine yet — add steps on the activity.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        if (activity != null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  unawaited(context.push('/activities/${activity!.id}')),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text('Edit ${activity!.name.trim()}'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 48),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One-liner hint for the supplies section when there's nothing to pull from.
class _NeedsHint extends StatelessWidget {
  const _NeedsHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }
}

/// The activity's supply pack list, rendered as chips — "pulled from the
/// activity's supply list". Resolves names from the supplies catalog; shows a
/// per-chip quantity when > 1.
class _SupplyChips extends ConsumerWidget {
  const _SupplyChips({required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final links =
        ref.watch(activitySupplyLinksProvider(activityId)).value ??
        const <ActivitySupply>[];
    final supplies = ref.watch(suppliesProvider).value ?? const <Supply>[];
    final nameById = {for (final s in supplies) s.id: s.name};

    if (links.isEmpty) {
      return const _NeedsHint(
        text:
            'No supplies on this activity yet — add a pack list on the '
            'activity.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in links)
              Chip(
                avatar: Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: scheme.onSecondaryContainer,
                ),
                label: Text(
                  _chipLabel(nameById[l.supplyId], l.quantity),
                ),
                backgroundColor: scheme.secondaryContainer,
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                side: BorderSide.none,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "pulled from the activity's supply list",
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  String _chipLabel(String? name, double? quantity) {
    final base = name ?? 'Removed supply';
    final qty = (quantity ?? 1).round();
    return qty > 1 ? '$base · $qty' : base;
  }
}
