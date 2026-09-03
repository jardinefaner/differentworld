import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/widgets/day_arc_strip.dart';
import 'package:differentworld/features/schedule/day_template.dart';
import 'package:differentworld/features/schedule/day_template_providers.dart';
import 'package:differentworld/features/schedule/widgets/apply_day_template_sheet.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/schedule/day-templates/:id` — the **day-template builder**. Set the
/// day's start + end once; add duration-blocks; drag to reorder and the
/// clock times re-pack automatically (the whole point — move blocks around
/// without re-typing times). "Apply to a day" materializes real
/// `schedule_blocks`. Every edit is optimistic (caps JSON → PowerSync).
class DayTemplateEditorScreen extends ConsumerWidget {
  const DayTemplateEditorScreen({required this.templateId, super.key});

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(dayTemplateByIdProvider(templateId));
    final spaceId = ref.watch(viewerProvider).spaceId;

    if (template == null || spaceId == null) {
      return const EdgeScaffold(
        backFallbackRoute: '/schedule/day-templates',
        body: EmptyState(
          icon: Icons.search_off,
          title: 'Template not found',
          message: 'It may have been deleted.',
        ),
      );
    }

    final actions = ref.read(dayTemplateActionsProvider);

    return EdgeScaffold(
      backFallbackRoute: '/schedule/day-templates',
      actions: [
        PrimaryActionButton(
          tooltip: 'Apply to a day',
          icon: Icons.event_available,
          onPressed: () => _apply(context, ref, template, spaceId),
        ),
        PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'rename') {
              unawaited(_rename(context, actions, template, spaceId));
            } else if (v == 'delete') {
              unawaited(_delete(context, ref, actions, template, spaceId));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Rename')),
            PopupMenuItem(value: 'delete', child: Text('Delete template')),
          ],
        ),
      ],
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderCard(
              template: template,
              spaceId: spaceId,
              onRename: () => _rename(context, actions, template, spaceId),
            ),
            // The arc the current order makes — redraws as blocks reorder, so
            // "the order matters" is visible while composing (docs/VISION.md).
            if (template.blocks.length >= 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: DayArcStrip(
                  energies: [
                    for (final b in template.blocks) b.energy ?? b.kind.energy,
                  ],
                  accent: Theme.of(context).colorScheme.primary,
                ),
              ),
            Expanded(
              child: template.blocks.isEmpty
                  ? const _NoBlocks()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: template.schedule.length,
                      onReorderItem: (oldIndex, newIndex) {
                        unawaited(
                          actions.reorderBlocks(
                            spaceId: spaceId,
                            templateId: template.id,
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          ),
                        );
                      },
                      itemBuilder: (context, i) {
                        final slot = template.schedule[i];
                        return _BlockTile(
                          key: ValueKey(slot.block.id),
                          slot: slot,
                          index: i,
                          onEdit: () => _editBlock(
                            context,
                            actions,
                            template,
                            spaceId,
                            slot.block,
                          ),
                          onDelete: () => actions.removeBlock(
                            spaceId: spaceId,
                            templateId: template.id,
                            blockId: slot.block.id,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    DayTemplateActions actions,
    DayTemplate template,
    String spaceId,
  ) async {
    final controller = TextEditingController(text: template.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Template name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Field-trip day'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return;
    await actions.renameTemplate(
      spaceId: spaceId,
      id: template.id,
      name: trimmed,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    DayTemplateActions actions,
    DayTemplate template,
    String spaceId,
  ) async {
    final router = GoRouter.of(context);
    // deleteWithUndo's snackbar rides the root messenger, so Undo still works
    // after the editor pops. The library lives in caps JSON (no Drift row), so
    // onUndo re-adds the in-scope DayTemplate model through the actions queue.
    await deleteWithUndo(
      context,
      label: 'template',
      onDelete: () => actions.deleteTemplate(spaceId: spaceId, id: template.id),
      onUndo: () =>
          actions.restoreTemplate(spaceId: spaceId, template: template),
    );
    if (router.canPop()) router.pop();
  }

  Future<void> _editBlock(
    BuildContext context,
    DayTemplateActions actions,
    DayTemplate template,
    String spaceId,
    DayBlock block,
  ) async {
    await showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BlockSheet(
        spaceId: spaceId,
        templateId: template.id,
        existing: block,
      ),
    );
  }

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    DayTemplate template,
    String spaceId,
  ) => showApplyDayTemplateSheet(context, template: template, spaceId: spaceId);
}

class _HeaderCard extends ConsumerWidget {
  const _HeaderCard({
    required this.template,
    required this.spaceId,
    required this.onRename,
  });
  final DayTemplate template;
  final String spaceId;
  final VoidCallback onRename;

  Future<void> _pickBound(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final minutes = isStart ? template.startMinute : template.endMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      helpText: isStart ? 'Day starts' : 'Day ends',
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    await ref
        .read(dayTemplateActionsProvider)
        .setBounds(
          spaceId: spaceId,
          id: template.id,
          startMinute: isStart ? m : template.startMinute,
          endMinute: isStart ? template.endMinute : m,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fillColor = template.isOverfilled
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final fillText = template.isOverfilled
        ? '${durationLabel(-template.freeMinutes)} over the day'
        : template.freeMinutes == 0
        ? 'Filled to the minute'
        : '${durationLabel(template.freeMinutes)} free';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onRename,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      template.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickBound(context, ref, isStart: true),
                  icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                  label: Text('Starts ${clockLabel(template.startMinute)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickBound(context, ref, isStart: false),
                  icon: const Icon(Icons.nightlight_outlined, size: 18),
                  label: Text('Ends ${clockLabel(template.endMinute)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                template.isOverfilled
                    ? Icons.warning_amber_rounded
                    : Icons.timelapse_outlined,
                size: 16,
                color: fillColor,
              ),
              const SizedBox(width: 6),
              Text(
                '${durationLabel(template.plannedMinutes)} planned · $fillText',
                style: theme.textTheme.bodySmall?.copyWith(color: fillColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => showGlassSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  _BlockSheet(spaceId: spaceId, templateId: template.id),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add block'),
          ),
          const Divider(height: 20),
        ],
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({
    required this.slot,
    required this.index,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });
  final DaySlot slot;
  final int index;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = slot.block;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Text(block.kind.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.label,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${clockLabel(slot.startMinute)}–'
                        '${clockLabel(slot.endMinute)} · '
                        '${durationLabel(block.minutes)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Remove block',
                  onPressed: () => unawaited(onDelete()),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      Icons.drag_handle,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoBlocks extends StatelessWidget {
  const _NoBlocks();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.view_timeline_outlined,
      title: 'No blocks yet',
      message:
          'Add the pieces of your day — arrival, snack, activity, '
          'outdoor, pickup. Drag to reorder; the times re-pack themselves.',
    );
  }
}

/// Add or edit a single block — kind, label, and a duration.
class _BlockSheet extends ConsumerStatefulWidget {
  const _BlockSheet({
    required this.spaceId,
    required this.templateId,
    this.existing,
  });
  final String spaceId;
  final String templateId;
  final DayBlock? existing;

  @override
  ConsumerState<_BlockSheet> createState() => _BlockSheetState();
}

class _BlockSheetState extends ConsumerState<_BlockSheet> {
  late DayBlockKind _kind;
  late int _minutes;
  late double _energy;
  late final TextEditingController _label;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _kind = e?.kind ?? DayBlockKind.activity;
    _minutes = e?.minutes ?? 30;
    _energy = e?.energy ?? _kind.energy;
    _label = TextEditingController(text: e?.label ?? '');
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  void _pickKind(DayBlockKind k) {
    setState(() {
      // If the label is empty or still the old kind's default, follow the
      // new kind — so picking "Outdoor" fills "Outdoor" for free.
      if (_label.text.trim().isEmpty || _label.text.trim() == _kind.label) {
        _label.text = k.label;
      }
      _kind = k;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.existing != null;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Edit block' : 'Add block',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 14),
              Text('Kind', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in DayBlockKind.values)
                    ChoiceChip(
                      label: Text('${k.emoji} ${k.label}'),
                      selected: _kind == k,
                      onSelected: (_) => _pickKind(k),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Text('Length', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in kBlockDurations)
                    ChoiceChip(
                      label: Text(durationLabel(d)),
                      selected: _minutes == d,
                      onSelected: (_) => setState(() => _minutes = d),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Energy in the arc', style: theme.textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in const [
                    ('Calm', 0.3),
                    ('Active', 0.6),
                    ('Peak', 0.9),
                  ])
                    ChoiceChip(
                      label: Text(e.$1),
                      selected: (_energy - e.$2).abs() < 0.15,
                      onSelected: (_) => setState(() => _energy = e.$2),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  final actions = ref.read(dayTemplateActionsProvider);
                  if (isEdit) {
                    await actions.updateBlock(
                      spaceId: widget.spaceId,
                      templateId: widget.templateId,
                      blockId: widget.existing!.id,
                      label: _label.text,
                      minutes: _minutes,
                      kind: _kind,
                      energy: _energy,
                    );
                  } else {
                    await actions.addBlock(
                      spaceId: widget.spaceId,
                      templateId: widget.templateId,
                      label: _label.text,
                      minutes: _minutes,
                      kind: _kind,
                    );
                  }
                  if (!mounted) return;
                  navigator.pop();
                },
                child: Text(isEdit ? 'Save' : 'Add block'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
