import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/child_world/child_world_model.dart';
import 'package:differentworld/features/child_world/child_world_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/groups/room_skin_background.dart';
import 'package:differentworld/features/groups/room_skins.dart';
import 'package:differentworld/features/heroes/heroes_providers.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/subjects/:id/world` — a child's own **world** (docs/VISION.md 2026-06-19:
/// the dailies / weeklies / projects arc, made personal). A bento of four
/// tiles, all THEIRS: their weekly intention, their own project, today's
/// answer + hero, and their growth. Intention + project are tappable to author
/// (set / advance); day + growth reflect data captured elsewhere.
class ChildWorldScreen extends ConsumerWidget {
  const ChildWorldScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    // Default to week 1 before the journey is set up, so the hub still works.
    final week = ref.watch(currentCurriculumWeekProvider) ?? 1;
    final name = subject?.firstName ?? 'This child';
    final key = (subjectId: subjectId, week: week);

    // Decal the hub with the child's room theme — subtle, over the Calm base.
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    Group? group;
    for (final g in groups) {
      if (g.id == subject?.groupId) {
        group = g;
        break;
      }
    }
    final skin = group == null ? null : roomSkinForGroup(group);

    return EdgeScaffold(
      background: skin == null
          ? null
          : RoomSkinBackground(skin: skin, decal: true, animate: true),
      actions: [
        _CastWeekButton(subjectKey: key, childName: name),
      ],
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            ContentHeader(title: '$name’s world', subtitle: 'This week'),
            BentoGrid(
              tiles: [
                BentoTile(
                  id: 'intention',
                  span: const BentoSpan.wide(),
                  child: _IntentionTile(subjectKey: key, childName: name),
                ),
                BentoTile(
                  id: 'project',
                  span: const BentoSpan.hero(),
                  child: _ProjectTile(subjectKey: key),
                ),
                BentoTile(
                  id: 'day',
                  span: const BentoSpan(phone: 1),
                  child: _DayTile(subjectId: subjectId),
                ),
                BentoTile(
                  id: 'growth',
                  span: const BentoSpan(phone: 1),
                  child: _GrowthTile(subjectId: subjectId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cast a child's WEEK to the room (docs/VISION.md 2026-06-20) — their world,
/// intention, project, and today's answer as a deck of slides via the generic
/// present engine. The opening slide always shows; the rest appear as the child
/// fills them in.
class _CastWeekButton extends ConsumerWidget {
  const _CastWeekButton({required this.subjectKey, required this.childName});

  final SubjectWeekKey subjectKey;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(currentWorldProvider);
    final intention = ref.watch(weeklyIntentionProvider(subjectKey)).value;
    final project = ref.watch(childProjectProvider(subjectKey)).value;
    final answer = ref.watch(todaysAnswerProvider(subjectKey.subjectId)).value;
    final accent = world?.color;

    return PrimaryActionButton(
      tooltip: 'Cast to the room',
      icon: Icons.cast,
      onPressed: () {
        final slides = <PresentSlide>[
          PresentSlide(
            eyebrow: 'THIS WEEK',
            title: '$childName’s world',
            subtitle: world?.name,
            emoji: world?.emoji,
            accent: accent,
          ),
          if (intention != null)
            PresentSlide(
              eyebrow: 'THE INTENTION',
              title: intention,
              icon: Icons.flag_outlined,
              accent: accent,
            ),
          if (project != null)
            PresentSlide(
              eyebrow: 'THE PROJECT',
              title: project.title,
              subtitle: _projectSubtitle(project),
              icon: Icons.handyman_outlined,
              accent: accent,
            ),
          if (answer != null)
            PresentSlide(
              eyebrow: 'TODAY ${childName.toUpperCase()} SAID',
              title: answer,
              icon: Icons.chat_bubble_outline,
              accent: accent,
            ),
        ];
        unawaited(
          presentSlides(context, title: '$childName’s world', slides: slides),
        );
      },
    );
  }

  String _projectSubtitle(ProjectView p) {
    final total = p.steps.length;
    final base = total == 0 ? 'A project' : '${p.done} of $total steps';
    if (total > 0 && p.done < total) return '$base · next: ${p.steps[p.done]}';
    return base;
  }
}

/// Shared tile chrome — a left-edge tinted card, optionally tappable.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.accent,
    required this.eyebrow,
    required this.child,
    this.onTap,
  });

  final Color accent;
  final String eyebrow;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // The bento cell is min-height / unbounded-max (it grows to fit), so
        // the tile shrink-wraps its content — no Expanded/Spacer (flex children
        // can't size against an unbounded height).
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        child: onTap == null
            ? body
            : InkWell(onTap: onTap, child: body),
      ),
    );
  }
}

class _IntentionTile extends ConsumerWidget {
  const _IntentionTile({required this.subjectKey, required this.childName});

  final SubjectWeekKey subjectKey;
  final String childName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final intention = ref.watch(weeklyIntentionProvider(subjectKey)).value;
    return _Tile(
      accent: ActivityPalette.indigo,
      eyebrow: 'their intention',
      onTap: () => unawaited(_editIntention(context, ref, subjectKey, intention)),
      child: intention == null
          ? Text(
              'Tap to set $childName’s intention for the week.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : Text(
              '“$intention”',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
    );
  }
}

class _ProjectTile extends ConsumerWidget {
  const _ProjectTile({required this.subjectKey});

  final SubjectWeekKey subjectKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final project = ref.watch(childProjectProvider(subjectKey)).value;
    final hasProject = project != null && project.hasProject;
    return _Tile(
      accent: ActivityPalette.teal,
      eyebrow: 'their project',
      onTap: () => unawaited(
        hasProject
            ? _openChecklist(context, ref, subjectKey, project)
            : _editProject(context, ref, subjectKey, null),
      ),
      child: !hasProject
          ? Text(
              'Tap to start a project — a title and a few steps.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: project.progress,
                    minHeight: 7,
                    backgroundColor: scheme.surface,
                    color: ActivityPalette.teal,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  project.isComplete
                      ? 'Done — every step ✓'
                      : 'Next: ${project.nextStep}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${project.doneClamped} of ${project.total} steps',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
    );
  }
}

class _DayTile extends ConsumerWidget {
  const _DayTile({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answer = ref.watch(todaysAnswerProvider(subjectId)).value;
    final hero = ref.watch(heroForSubjectProvider(subjectId)).value;
    return _Tile(
      accent: ActivityPalette.amber,
      eyebrow: 'their day',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (answer != null)
            Text(
              '“$answer”',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              'No answer yet today.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (hero != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.shield_moon_outlined,
                  size: 16,
                  color: ActivityPalette.amber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hero.data.name,
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GrowthTile extends ConsumerWidget {
  const _GrowthTile({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collection = ref.watch(actionWordsCollectionProvider(subjectId)).value;
    final title = collection?.emergingTitle;
    final days = collection?.dayCount ?? 0;
    return _Tile(
      accent: ActivityPalette.green,
      eyebrow: 'their growth',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            )
          else
            Text(
              'Growing — their story builds as they play.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            days == 1 ? '1 day in their world' : '$days days in their world',
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── authoring ────────────────────────────────────────────────────────────────

Future<void> _editIntention(
  BuildContext context,
  WidgetRef ref,
  SubjectWeekKey key,
  String? current,
) async {
  final controller = TextEditingController(text: current ?? '');
  final result = await showGlassSheet<String>(
    context: context,
    builder: (_) => _IntentionSheet(controller: controller),
  );
  controller.dispose();
  if (result == null) return;
  unawaited(HapticFeedback.selectionClick());
  await ref
      .read(entryActionsProvider)
      .setWeeklyIntention(
        subjectId: key.subjectId,
        week: key.week,
        text: result,
      );
}

Future<void> _editProject(
  BuildContext context,
  WidgetRef ref,
  SubjectWeekKey key,
  ProjectView? current,
) async {
  final result = await showGlassSheet<({String title, List<String> steps})>(
    context: context,
    builder: (_) => _ProjectSheet(current: current),
  );
  if (result == null) return;
  unawaited(HapticFeedback.selectionClick());
  await ref
      .read(entryActionsProvider)
      .setProject(
        subjectId: key.subjectId,
        week: key.week,
        title: result.title,
        steps: result.steps,
      );
}

Future<void> _openChecklist(
  BuildContext context,
  WidgetRef ref,
  SubjectWeekKey key,
  ProjectView project,
) async {
  final wantsEdit = await showGlassSheet<bool>(
    context: context,
    builder: (_) => _ProjectChecklistSheet(subjectKey: key, project: project),
  );
  // The checklist has popped; THIS context + ref (the tile's) are still mounted,
  // so opening the editor here avoids dispatching on the checklist's now-dead
  // context (interaction invariant #3).
  if (wantsEdit == true && context.mounted) {
    await _editProject(context, ref, key, project);
  }
}

/// Set / edit a child's weekly intention.
class _IntentionSheet extends StatelessWidget {
  const _IntentionSheet({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GlassDragHandle(),
            const SizedBox(height: 8),
            Text('Their intention', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'One thing they want for the week — in their own words.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. I want to be brave',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Create / edit a child's project — a title + ordered steps.
class _ProjectSheet extends StatefulWidget {
  const _ProjectSheet({required this.current});

  final ProjectView? current;

  @override
  State<_ProjectSheet> createState() => _ProjectSheetState();
}

class _ProjectSheetState extends State<_ProjectSheet> {
  late final TextEditingController _title;
  late final List<TextEditingController> _steps;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.current?.title ?? '');
    final existing = widget.current?.steps ?? const <String>[];
    _steps = [
      for (final s in existing) TextEditingController(text: s),
      if (existing.isEmpty) TextEditingController(),
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _steps) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isDirty =>
      _title.text.trim().isNotEmpty ||
      _steps.any((c) => c.text.trim().isNotEmpty);

  void _save() {
    final title = _title.text.trim();
    final steps = [
      for (final c in _steps)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    if (title.isEmpty) return;
    Navigator.of(context).pop((title: title, steps: steps));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DismissGuard(
      isDirty: () => _isDirty,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GlassDragHandle(),
                const SizedBox(height: 8),
                Text(
                  widget.current == null ? 'Start a project' : 'Edit project',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  autofocus: widget.current == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Project',
                    hintText: 'e.g. Build a coral-reef diorama',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Steps', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    // Key on the controller (its stable identity) so removing a
                    // NON-last step doesn't shift Element matching and tear down
                    // a focused TextField's IME (the keys gotcha; index keys are
                    // wrong here because indices shift on remove).
                    key: ObjectKey(_steps[i]),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _steps[i],
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Step ${i + 1}',
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove step',
                          onPressed: _steps.length == 1
                              ? null
                              : () => setState(() => _steps.removeAt(i).dispose()),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () =>
                        setState(() => _steps.add(TextEditingController())),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add a step'),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Save project'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tick off a project's steps — each tap persists the progress.
class _ProjectChecklistSheet extends ConsumerWidget {
  const _ProjectChecklistSheet({
    required this.subjectKey,
    required this.project,
  });

  final SubjectWeekKey subjectKey;
  final ProjectView project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Re-watch so the checklist reflects each tap live.
    final live = ref.watch(childProjectProvider(subjectKey)).value ?? project;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GlassDragHandle(),
              const SizedBox(height: 8),
              Text(live.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${live.doneClamped} of ${live.total} done',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < live.steps.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: i < live.doneClamped,
                  title: Text(live.steps[i]),
                  onChanged: (_) {
                    unawaited(HapticFeedback.selectionClick());
                    // Sequential model: tapping step i completes through i, or
                    // un-completes from i onward if it was already done.
                    final done = i < live.doneClamped ? i : i + 1;
                    unawaited(
                      ref
                          .read(entryActionsProvider)
                          .setProjectProgress(
                            subjectId: subjectKey.subjectId,
                            week: subjectKey.week,
                            done: done,
                          ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                // Return a signal; the caller (_openChecklist, on the stable
                // tile context) opens the editor — no dispatch on this sheet's
                // dead context after pop.
                onPressed: () => Navigator.of(context).pop(true),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit title or steps'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
