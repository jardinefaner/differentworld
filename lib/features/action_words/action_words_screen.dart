import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/reveal_overlay.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/widgets/verb_grid.dart';
import 'package:differentworld/features/action_words/widgets/world_badge.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
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
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// The morning pick (the brief's VERBS screen): every kid in the room,
/// tap a name → tap 3 of 12 verbs → the teacher sees which world the combo
/// reveals (kids don't, until the closing reveal). ~10 seconds per kid.
class ActionWordsScreen extends ConsumerWidget {
  const ActionWordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'Our worlds',
          icon: const Icon(Icons.menu_book_outlined),
          onPressed: () => context.push('/action-words/worlds'),
        ),
        IconButton(
          tooltip: 'Send home',
          icon: const Icon(Icons.outgoing_mail),
          onPressed: () => context.push('/action-words/send'),
        ),
        const SyncStatusIndicator(),
      ],
      body: subjectsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load children',
          onRetry: () => ref.invalidate(subjectsInSpaceProvider),
        ),
        data: (subjects) {
          if (subjects.isEmpty) {
            return const EmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'No children yet',
              message: 'Add children to your program, then pick each one’s '
                  'three action words for the day.',
            );
          }
          return ResponsivePage(
            children: [
              ContentHeader(
                title: 'Today’s words',
                subtitle: DateFormat.yMMMMEEEEd().format(DateTime.now()),
              ),
              const _WorldsBanner(),
              for (final s in subjects)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _KidRow(subject: s),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A tappable banner into the program's Different Worlds — the bigger
/// worlds the rooms step into, that the daily picks nest inside.
class _WorldsBanner extends StatelessWidget {
  const _WorldsBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gold = WorldBadge.goldFor(theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push('/action-words/different-worlds'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Text('🌍', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Different Worlds',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'The worlds your rooms step into',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KidRow extends ConsumerWidget {
  const _KidRow({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref
        .watch(actionWordsForDayProvider(
          (subjectId: subject.id, date: todayKey()),
        ))
        .value;
    final picks = day?.verbPicks ?? const <String>[];
    final hasPicks = day?.hasPicks ?? false;
    final match = (day?.hasPicks ?? false)
        ? resolveWorld(day!.verbPicks.toSet(), ref.watch(classWorldBookProvider))
        : null;
    final fullName = '${subject.firstName} ${subject.lastName}'.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => _openPick(context, ref, subject, picks),
        // Long-press → the child's world collection over time.
        onLongPress: () => context.push('/action-words/${subject.id}'),
        leading: _Leading(match: match),
        title: Text(fullName),
        subtitle: hasPicks
            ? Text(
                verbsByIds(picks).map((v) => v.emoji).join('  '),
                style: const TextStyle(fontSize: 18),
              )
            : Text(
                'Tap to pick today’s 3 words',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
        trailing: hasPicks
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dots(done: day!.doneCount, total: kPicksPerDay),
                  IconButton(
                    tooltip: 'Reveal ${subject.firstName}’s world',
                    icon: const Icon(Icons.auto_awesome),
                    color: WorldBadge.goldFor(theme),
                    onPressed: () => RevealOverlay.show(
                      context,
                      subject: subject,
                      day: day,
                    ),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({this.match});
  final WorldMatch? match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final emoji = match?.world?.emoji;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: emoji != null
          ? Text(emoji, style: const TextStyle(fontSize: 24))
          : Icon(
              Icons.circle_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              i < done ? Icons.circle : Icons.circle_outlined,
              size: 12,
              color: i < done
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

Future<void> _openPick(
  BuildContext context,
  WidgetRef ref,
  Subject subject,
  List<String> initial,
) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PickSheet(subject: subject, initial: initial),
  );
}

class _PickSheet extends ConsumerStatefulWidget {
  const _PickSheet({required this.subject, required this.initial});

  final Subject subject;
  final List<String> initial;

  @override
  ConsumerState<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends ConsumerState<_PickSheet> {
  late final Set<String> _selected = widget.initial.toSet();
  bool _saving = false;

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id) && _selected.length < kPicksPerDay) {
        _selected.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_saving || _selected.length != kPicksPerDay) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    unawaited(HapticFeedback.selectionClick());
    await ref.read(actionWordsActionsProvider).setPicks(
          subjectId: widget.subject.id,
          groupId: widget.subject.groupId,
          date: todayKey(),
          verbIds: _selected.toList(),
        );
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName =
        '${widget.subject.firstName} ${widget.subject.lastName}'.trim();
    final ready = _selected.length == kPicksPerDay;
    final match = ready
        ? resolveWorld(_selected, ref.watch(classWorldBookProvider))
        : null;

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
              Text(fullName, style: theme.textTheme.titleLarge),
              Text(
                ready
                    ? 'Their world today'
                    : 'Tap 3 words (${_selected.length}/$kPicksPerDay)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              VerbGrid(selected: _selected, onToggle: _toggle),
              if (match != null) ...[
                const SizedBox(height: 20),
                WorldBadge(match: match, showVerbs: false, emojiSize: 56),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      unawaited(
                        context.push(
                          '/action-words/activities?verbs='
                          '${_selected.join(',')}',
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_activity_outlined, size: 18),
                    label: const Text('See matching activities'),
                  ),
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
                    onPressed: ready && !_saving ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Save'),
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
