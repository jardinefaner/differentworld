import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/activity_match.dart';
import 'package:differentworld/features/action_words/curriculum_import.dart';
import 'package:differentworld/features/action_words/senses.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/widgets/verb_grid.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The brief's ACTIVITIES screen — once words are picked, the matched
/// activities from the library (those tagged with the same verbs). Tap
/// words to filter; tag any activity with the 3 words it practices. The
/// "DO" surface, connecting verbs → real physical activities.
class ActivityMatchScreen extends ConsumerStatefulWidget {
  const ActivityMatchScreen({this.initialVerbs = const [], super.key});

  final List<String> initialVerbs;

  @override
  ConsumerState<ActivityMatchScreen> createState() =>
      _ActivityMatchScreenState();
}

class _ActivityMatchScreenState extends ConsumerState<ActivityMatchScreen> {
  // null = follow today's most-picked cohort verbs (the auto default, so the
  // matcher opens already showing what fits the room — THE_DAY.md's 15-second
  // Verb-Hour touch). A non-null Set = the teacher's explicit filter.
  Set<String>? _override;

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final isDirector = ref.watch(viewerProvider).isDirector;
    // The default lens: explicit initialVerbs if passed, else today's most-
    // picked cohort verbs (live until the teacher taps a chip).
    final autoDefault = widget.initialVerbs.isNotEmpty
        ? widget.initialVerbs.toSet()
        : ref.watch(todaysTopPickedVerbsProvider).toSet();
    final filter = _override ?? autoDefault;
    final following = _override == null && autoDefault.isNotEmpty;
    return EdgeScaffold(
      actions: [
        if (isDirector)
          IconButton(
            tooltip: 'Import the curriculum’s activities',
            icon: const Icon(Icons.library_add_outlined),
            onPressed: _import,
          ),
        IconButton(
          tooltip: 'New activity',
          icon: const Icon(Icons.add),
          onPressed: () => showGlassSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const _NewActivitySheet(),
          ),
        ),
        const SyncStatusIndicator(),
      ],
      body: activitiesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load activities',
          onRetry: () => ref.invalidate(activitiesProvider),
        ),
        data: (activities) {
          final active =
              activities.where((a) => a.archivedAt == null).toList();
          if (active.isEmpty) {
            return EmptyState(
              icon: Icons.local_activity_outlined,
              title: 'No activities yet',
              message: isDirector
                  ? 'Import the 10-week curriculum’s activities — each one '
                      'tagged with the verbs it practices — or add your own.'
                  : 'Add activities in your Schedule first, then tag each '
                      'one with the three action words it practices — they’ll '
                      'show up here when those words are picked.',
              action: isDirector
                  ? FilledButton.icon(
                      onPressed: _import,
                      icon: const Icon(Icons.library_add_outlined),
                      label: const Text('Import curriculum activities'),
                    )
                  : null,
            );
          }
          final matches = filter.isEmpty
              ? [for (final a in active) ActivityMatch(activity: a, overlap: 0)]
              : matchActivities(filter, active);

          return ResponsivePage(
            children: [
              ContentHeader(
                title: 'Activities',
                subtitle: following
                    ? "Matching today's most-picked words — tap any to change."
                    : 'Tap words to find matches; tag an activity with the '
                          'words it practices.',
              ),
              _VerbFilter(
                selected: filter,
                onToggle: (id) => setState(() {
                  final next = {...filter};
                  if (!next.remove(id)) next.add(id);
                  _override = next;
                }),
              ),
              if (_override != null && widget.initialVerbs.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _override = null),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text("Back to today's picks"),
                  ),
                ),
              const SizedBox(height: 12),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No activities match those words yet — tag some below, '
                    'or pick fewer words.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                )
              else
                for (final m in matches)
                  _ActivityCard(
                    activity: m.activity,
                    overlap: m.overlap,
                    onTag: () => _openTag(m.activity),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openTag(Activity activity) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TagSheet(activity: activity),
    );
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final n = await ref.read(curriculumImporterProvider).importActivities();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'All curriculum activities are already in your library.'
              : 'Added $n curriculum ${n == 1 ? "activity" : "activities"} — '
                  'tagged with their verbs.',
        ),
      ),
    );
  }
}

class _VerbFilter extends StatelessWidget {
  const _VerbFilter({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final v in kVerbs)
          FilterChip(
            label: Text('${v.emoji} ${v.label}'),
            selected: selected.contains(v.id),
            onSelected: (_) => onToggle(v.id),
          ),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.activity,
    required this.overlap,
    required this.onTag,
  });

  final Activity activity;
  final int overlap;
  final VoidCallback onTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = activityVerbs(activity);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    activity.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (overlap >= 2)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      Icons.star,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                IconButton(
                  tooltip: 'Tag words',
                  icon: const Icon(Icons.sell_outlined, size: 20),
                  onPressed: onTag,
                ),
              ],
            ),
            if (activity.description != null &&
                activity.description!.isNotEmpty)
              Text(
                activity.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            if (tags.isEmpty)
              Text(
                'Not tagged yet',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final v in verbsByIds(tags))
                    Text('${v.emoji} ${v.label}',
                        style: theme.textTheme.bodySmall),
                  for (final s in activitySenses(activity))
                    Text(s.emoji, style: const TextStyle(fontSize: 14)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TagSheet extends ConsumerStatefulWidget {
  const _TagSheet({required this.activity});

  final Activity activity;

  @override
  ConsumerState<_TagSheet> createState() => _TagSheetState();
}

class _TagSheetState extends ConsumerState<_TagSheet> {
  late final Set<String> _selected = activityVerbs(widget.activity).toSet();
  late final Set<Sense> _senses = activitySenses(widget.activity).toSet();
  bool _saving = false;

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id) && _selected.length < kPicksPerDay) {
        _selected.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    unawaited(HapticFeedback.selectionClick());
    await ref.read(activityActionsProvider).setActivityTags(
          widget.activity,
          verbs: _selected.toList(),
          senses: _senses.map((s) => s.name).toList(),
        );
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GlassDragHandle(bottomMargin: 16),
              Text(widget.activity.name, style: theme.textTheme.titleLarge),
              Text(
                'Which 3 words does this practice?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              VerbGrid(selected: _selected, onToggle: _toggle),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Senses', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in Sense.values)
                    FilterChip(
                      label: Text('${s.emoji} ${s.label}'),
                      selected: _senses.contains(s),
                      onSelected: (_) => setState(() {
                        if (!_senses.remove(s)) _senses.add(s);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save tags'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add a custom activity from the library — name, instruction, the words
/// it practices, and the senses it engages. Saved tagged so it shows in
/// the matcher right away.
class _NewActivitySheet extends ConsumerStatefulWidget {
  const _NewActivitySheet();

  @override
  ConsumerState<_NewActivitySheet> createState() => _NewActivitySheetState();
}

class _NewActivitySheetState extends ConsumerState<_NewActivitySheet> {
  final _name = TextEditingController();
  final _instruction = TextEditingController();
  final Set<String> _verbs = {};
  final Set<Sense> _senses = {};
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _instruction.dispose();
    super.dispose();
  }

  void _toggleVerb(String id) {
    setState(() {
      if (!_verbs.remove(id) && _verbs.length < kPicksPerDay) _verbs.add(id);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the activity a name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    unawaited(HapticFeedback.selectionClick());
    await ref.read(activityActionsProvider).createTagged(
          name: name,
          description: _instruction.text.trim().isEmpty
              ? null
              : _instruction.text.trim(),
          verbs: _verbs.toList(),
          senses: _senses.map((s) => s.name).toList(),
        );
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GlassDragHandle(bottomMargin: 16),
              Text('New activity', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Heavy Helper',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instruction,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'One-sentence instruction (optional)',
                  hintText: 'Carry the heaviest thing you safely can to a '
                      'friend.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Words it practices',
                    style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 6),
              VerbGrid(selected: _verbs, onToggle: _toggleVerb),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Senses', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in Sense.values)
                    FilterChip(
                      label: Text('${s.emoji} ${s.label}'),
                      selected: _senses.contains(s),
                      onSelected: (_) => setState(() {
                        if (!_senses.remove(s)) _senses.add(s);
                      }),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
