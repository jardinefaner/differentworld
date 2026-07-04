import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/widgets/day_arc_strip.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/day_template.dart';
import 'package:differentworld/features/schedule/day_template_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The day the app DRAFTS for today — the "propose the day" move (docs/VISION.md
/// "the app walks in already holding a draft of your day"). Built rules-based
/// (offline, deterministic) from the program's hours + this week's world; the
/// director accepts or tweaks it. Re-reads on any world / phase-window change.
final proposedDayProvider = Provider<DayTemplate>((ref) {
  final windows = ref.watch(dayPhaseWindowsProvider);
  final world = ref.watch(currentWorldProvider);
  return DayTemplate.proposed(
    startMinute: windows.arrivalStart,
    endMinute: windows.closedStart,
    worldName: world?.name,
  );
});

/// In-flight guard for apply / tweak — lives in a provider (NOT widget state) so
/// it survives a widget rebuild (e.g. a device rotation mid-apply). A local flag
/// resets when Flutter recreates the State, reopening the double-apply race; a
/// provider flag does not.
class _BusyNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  bool get busy => state;
  set busy(bool v) => state = v;
}

final _proposeBusyProvider = NotifierProvider<_BusyNotifier, bool>(
  _BusyNotifier.new,
);

/// `/propose-day` — review the drafted day and either use it (drops onto today's
/// schedule) or tweak it first (saves it to the library + opens the editor).
/// Nothing is written until the host accepts.
class ProposeDayScreen extends ConsumerStatefulWidget {
  const ProposeDayScreen({super.key});

  @override
  ConsumerState<ProposeDayScreen> createState() => _ProposeDayScreenState();
}

class _ProposeDayScreenState extends ConsumerState<ProposeDayScreen> {
  String? _groupId;

  Group? _resolve(List<Group> groups) {
    for (final g in groups) {
      if (g.id == _groupId) return g;
    }
    return groups.isEmpty ? null : groups.first;
  }

  Future<void> _pickGroup(List<Group> groups) async {
    final picked = await showGlassSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final g in groups)
              ListTile(
                title: Text(g.name),
                trailing: g.id == _resolve(groups)?.id
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop(g.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _groupId = picked);
  }

  Future<void> _use(String spaceId, DayTemplate template, Group group) async {
    if (ref.read(_proposeBusyProvider)) return;
    ref.read(_proposeBusyProvider.notifier).busy = true;
    try {
      // Await the REAL current-day blocks (not a possibly-stale stream snapshot,
      // which reads empty on a cold launch) so we never silently stack the draft
      // on top of a day another teacher already built.
      final key = (groupId: group.id, date: todayKey());
      final existing = await ref.read(
        scheduleDayForGroupProvider(key).future,
      );
      if (!mounted) return;
      if (existing.isNotEmpty) {
        final ok = await confirmDestructive(
          context,
          title: '${group.name} already has ${existing.length} blocks today',
          message:
              'Add the drafted day on top? You can delete extras in the '
              'schedule afterwards.',
          confirmLabel: 'Add anyway',
        );
        if (!ok || !mounted) return;
      }
      final n = await ref
          .read(dayTemplateActionsProvider)
          .applyTemplateToDate(
            spaceId: spaceId,
            template: template,
            date: DateTime.now(),
            groupIds: [group.id],
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Today's day is set — $n blocks")),
      );
      context.go('/run-day');
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't set today's day")),
      );
    } finally {
      ref.read(_proposeBusyProvider.notifier).busy = false;
    }
  }

  Future<void> _tweak(String spaceId, DayTemplate template) async {
    if (ref.read(_proposeBusyProvider)) return;
    ref.read(_proposeBusyProvider.notifier).busy = true;
    try {
      // Save the draft to the library (idempotent by id), then open the editor.
      await ref
          .read(dayTemplateActionsProvider)
          .restoreTemplate(spaceId: spaceId, template: template);
      if (!mounted) return;
      unawaited(context.push('/schedule/day-templates/${template.id}'));
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the editor")),
      );
    } finally {
      ref.read(_proposeBusyProvider.notifier).busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    // Distinguish "still syncing" (null space) from "no permission" — a loader,
    // not a lockout, while the space row is on its way.
    if (spaceId == null) {
      return const EdgeScaffold(
        backFallbackRoute: '/run-day',
        body: LoadingSlot(),
      );
    }
    if (!viewer.canManageSchedule) {
      return const EdgeScaffold(
        backFallbackRoute: '/run-day',
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Drafting a day is a lead task',
          message:
              'Your director or a lead teacher sets the day. Ask them to '
              'draft one.',
        ),
      );
    }

    final theme = Theme.of(context);
    final proposed = ref.watch(proposedDayProvider);
    final world = ref.watch(currentWorldProvider);
    final accent = world?.color ?? theme.colorScheme.primary;
    final groupsAsync = ref.watch(groupsProvider);
    final groups = groupsAsync.value ?? const <Group>[];
    final busy = ref.watch(_proposeBusyProvider);

    return EdgeScaffold(
      backFallbackRoute: '/run-day',
      actions: [
        if (groups.length > 1)
          IconButton(
            tooltip: 'Choose cohort',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => unawaited(_pickGroup(groups)),
          ),
        const SyncStatusIndicator(),
      ],
      body: groupsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load your cohorts',
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (gs) {
          final group = _resolve(gs);
          final slots = proposed.schedule;
          // "Explain the arc" — one "why it sits here" per block, from the
          // day's energy shape (docs/VISION.md "show its reasoning").
          final why = dayArcNarrative([
            for (final s in slots)
              (s.block.energy ?? s.block.kind.energy).clamp(0.0, 1.0),
          ]);
          return SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  children: [
                    ContentHeader(
                      title: 'Here’s a day for today',
                      subtitle: world == null
                          ? 'Drafted from your '
                                '${clockLabel(proposed.startMinute)}–'
                                '${clockLabel(proposed.endMinute)} hours · '
                                'nothing saved yet'
                          : 'Drafted from ${world.name} · '
                                '${clockLabel(proposed.startMinute)}–'
                                '${clockLabel(proposed.endMinute)} · nothing '
                                'saved yet',
                    ),
                    // Multi-cohort: make the target explicit, not a guess.
                    if (gs.length > 1 && group != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: () => unawaited(_pickGroup(gs)),
                            icon: const Icon(Icons.groups_outlined, size: 18),
                            label: Text('For ${group.name}'),
                          ),
                        ),
                      ),
                    if (slots.length >= 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DayArcStrip(
                          energies: [
                            for (final s in slots)
                              s.block.energy ?? s.block.kind.energy,
                          ],
                          accent: accent,
                        ),
                      ),
                    for (var i = 0; i < slots.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slots[i].block.kind.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 12),
                            // minWidth (not fixed) so the clock can grow at
                            // 200% text scale without clipping.
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 56),
                              child: Text(
                                clockLabel(slots[i].startMinute),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    slots[i].block.label,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (i < why.length)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Text(
                                        why[i],
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              durationLabel(slots[i].block.minutes),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: (group == null || busy)
                                ? null
                                : () =>
                                      unawaited(_use(spaceId, proposed, group)),
                            icon: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            label: const Text('Use this day'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => unawaited(_tweak(spaceId, proposed)),
                          child: const Text('Tweak first'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Drops onto today’s schedule — you can still change '
                      'anything.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
