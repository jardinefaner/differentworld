import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/activity_match.dart';
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
  late final Set<String> _filter = widget.initialVerbs.toSet();

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(activitiesProvider);
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
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
            return const EmptyState(
              icon: Icons.local_activity_outlined,
              title: 'No activities yet',
              message: 'Add activities in your Schedule first, then tag each '
                  'one with the three action words it practices — they’ll '
                  'show up here when those words are picked.',
            );
          }
          final matches = _filter.isEmpty
              ? [for (final a in active) ActivityMatch(activity: a, overlap: 0)]
              : matchActivities(_filter, active);

          return ResponsivePage(
            children: [
              const ContentHeader(
                title: 'Activities',
                subtitle: 'Tap words to find matches; tag an activity with '
                    'the words it practices.',
              ),
              _VerbFilter(
                selected: _filter,
                onToggle: (id) => setState(() {
                  if (!_filter.remove(id)) _filter.add(id);
                }),
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
                children: [
                  for (final v in verbsByIds(tags))
                    Text('${v.emoji} ${v.label}',
                        style: theme.textTheme.bodySmall),
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
    await ref
        .read(activityActionsProvider)
        .setActionVerbs(widget.activity, _selected.toList());
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(widget.activity.name, style: theme.textTheme.titleLarge),
              Text(
                'Which 3 words does this practice?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              VerbGrid(selected: _selected, onToggle: _toggle),
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
