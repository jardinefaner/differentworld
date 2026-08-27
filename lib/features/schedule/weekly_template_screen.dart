import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/schedule/template` — Wave 154 MVP author surface for the
/// program's default weekly pattern. Per cohort × day-of-week list
/// of slots; "+ Slot" form for each (cohort, day) cell; "Generate
/// next 4 weeks" button materializes schedule_blocks.
///
/// V1 is list-shaped (vertical per-cohort, days as expandable
/// groups). The drag-drop matrix is a polish pass once this MVP
/// has been used in production for a term.
class WeeklyTemplateScreen extends ConsumerWidget {
  const WeeklyTemplateScreen({super.key});

  static const _daysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guard the SCREEN, not just the button. Every one of these was
    // reachable by deep link and by search with no check at all, so
    // hiding the entry point was never the same as gating the action.
    if (!ref.watch(viewerProvider).canManageSchedule) {
      return const EdgeScaffold(
        backFallbackRoute: '/schedule',
        body: NoAccess(
          title: 'You can’t edit the weekly shape yet.',
          message:
              'This sets what repeats every week for the whole program. Ask whoever runs the schedule.',
        ),
      );
    }
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    final dbAsync = ref.watch(appDatabaseProvider);

    return EdgeScaffold(
      backFallbackRoute: '/schedule',
      actions: [
        PrimaryActionButton(
          tooltip: 'Generate next 4 weeks',
          icon: Icons.event_repeat,
          onPressed: () => _generate(context, ref),
        ),
      ],
      body: dbAsync.when(
        loading: () => const LoadingSlot(),
        error: (e, _) => ErrorState(
          title: 'Could not load the schedule',
          onRetry: () => ref.invalidate(appDatabaseProvider),
        ),
        data: (db) {
          if (spaceId == null) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Sign in to author the schedule',
            );
          }
          return StreamBuilder<WeeklyTemplate?>(
            stream: db.weeklyTemplateDao.watchDefault(spaceId: spaceId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingSlot();
              }
              final template = snap.data;
              if (template == null) {
                return _NoTemplate(spaceId: spaceId);
              }
              return _TemplateBody(template: template);
            },
          );
        },
      ),
    );
  }

  Future<void> _generate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final viewer = ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) return;
    final db = await ref.read(appDatabaseProvider.future);
    final template = await db.weeklyTemplateDao
        .watchDefault(spaceId: spaceId)
        .first;
    if (template == null) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Create the template first.')),
      );
      return;
    }
    if (!context.mounted) return;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 28));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Generate 4 weeks of blocks?'),
        content: Text(
          'This will add schedule blocks for every slot in the '
          'template from ${_dateLabel(start)} through ${_dateLabel(end)}. '
          'Existing blocks in this range are NOT removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final n = await db.weeklyTemplateDao.generateBlocks(
      spaceId: spaceId,
      templateId: template.id,
      fromDate: start,
      toDate: end,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text('Generated $n blocks.')),
    );
  }
}

String _dateLabel(DateTime d) => '${d.month}/${d.day}/${d.year}';

class _NoTemplate extends ConsumerWidget {
  const _NoTemplate({required this.spaceId});
  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ContentHeader(
              title: 'No template yet',
              subtitle:
                  'Set up your default week — '
                  'activities at each time slot, per cohort.',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create default week'),
              onPressed: () async {
                final viewer = ref.read(viewerProvider);
                final db = await ref.read(appDatabaseProvider.future);
                if (!context.mounted) return;
                await db.weeklyTemplateDao.createTemplate(
                  spaceId: spaceId,
                  createdBy: viewer.memberId,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateBody extends ConsumerWidget {
  const _TemplateBody({required this.template});
  final WeeklyTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dbAsync = ref.watch(appDatabaseProvider);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    if (dbAsync.value == null) return const LoadingSlot();
    final db = dbAsync.value!;
    return StreamBuilder<List<WeeklyTemplateBlock>>(
      stream: db.weeklyTemplateDao.watchSlots(templateId: template.id),
      builder: (context, snap) {
        final slots = snap.data ?? const <WeeklyTemplateBlock>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            ContentHeader(
              title: template.name,
              subtitle:
                  '${slots.length} ${slots.length == 1 ? "slot" : "slots"} • '
                  '${groups.length} cohort${groups.length == 1 ? "" : "s"}',
            ),
            for (final group in groups) ...[
              const SizedBox(height: 12),
              Text(
                group.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              for (var dow = 0; dow < 7; dow++)
                _DayRow(
                  group: group,
                  template: template,
                  dayOfWeek: dow,
                  dayLabel: WeeklyTemplateScreen._daysShort[dow],
                  slots: slots
                      .where(
                        (s) => s.groupId == group.id && s.dayOfWeek == dow,
                      )
                      .toList(),
                  activities: activities,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _DayRow extends ConsumerWidget {
  const _DayRow({
    required this.group,
    required this.template,
    required this.dayOfWeek,
    required this.dayLabel,
    required this.slots,
    required this.activities,
  });

  final Group group;
  final WeeklyTemplate template;
  final int dayOfWeek;
  final String dayLabel;
  final List<WeeklyTemplateBlock> slots;
  final List<Activity> activities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      dayLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      slots.isEmpty
                          ? 'No slots'
                          : '${slots.length} '
                                '${slots.length == 1 ? "slot" : "slots"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _openSlotSheet(context, ref),
                    tooltip: 'Add slot',
                  ),
                ],
              ),
              for (final s in slots) _SlotRow(slot: s, activities: activities),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSlotSheet(BuildContext context, WidgetRef ref) async {
    await showGlassSheet<void>(
      context: context,
      builder: (ctx) => _SlotEditSheet(
        group: group,
        template: template,
        dayOfWeek: dayOfWeek,
        dayLabel: dayLabel,
        activities: activities,
      ),
    );
  }
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({required this.slot, required this.activities});
  final WeeklyTemplateBlock slot;
  final List<Activity> activities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activity = slot.activityId == null
        ? null
        : activities.where((a) => a.id == slot.activityId).firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const SizedBox(width: 48),
          Expanded(
            child: Text(
              '${slot.startTime}–${slot.endTime} · '
              '${activity?.name ?? "—"}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () async {
              final db = await ref.read(appDatabaseProvider.future);
              if (!context.mounted) return;
              await deleteWithUndo(
                context,
                label: 'slot',
                onDelete: () => db.weeklyTemplateDao.deleteSlot(slot.id),
                onUndo: () => db.weeklyTemplateDao.restoreSlot(slot),
              );
            },
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }
}

class _SlotEditSheet extends ConsumerStatefulWidget {
  const _SlotEditSheet({
    required this.group,
    required this.template,
    required this.dayOfWeek,
    required this.dayLabel,
    required this.activities,
  });
  final Group group;
  final WeeklyTemplate template;
  final int dayOfWeek;
  final String dayLabel;
  final List<Activity> activities;

  @override
  ConsumerState<_SlotEditSheet> createState() => _SlotEditSheetState();
}

class _SlotEditSheetState extends ConsumerState<_SlotEditSheet> {
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 9, minute: 30);
  Activity? _activity;

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.group.name} · ${widget.dayLabel}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _start,
                    );
                    if (picked != null) setState(() => _start = picked);
                  },
                  child: Text('Start ${_hhmm(_start)}'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _end,
                    );
                    if (picked != null) setState(() => _end = picked);
                  },
                  child: Text('End ${_hhmm(_end)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Activity?>(
            initialValue: _activity,
            decoration: const InputDecoration(
              labelText: 'Activity',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(child: Text('—')),
              for (final a in widget.activities)
                DropdownMenuItem(value: a, child: Text(a.name)),
            ],
            onChanged: (a) => setState(() => _activity = a),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () async {
              final viewer = ref.read(viewerProvider);
              final spaceId = viewer.requireSpaceId(action: 'save slot');
              final navigator = Navigator.of(context);
              final db = await ref.read(appDatabaseProvider.future);
              await db.weeklyTemplateDao.addSlot(
                templateId: widget.template.id,
                spaceId: spaceId,
                groupId: widget.group.id,
                dayOfWeek: widget.dayOfWeek,
                startTime: _hhmm(_start),
                endTime: _hhmm(_end),
                activityId: _activity?.id,
              );
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Save slot'),
          ),
        ],
      ),
    );
  }
}
