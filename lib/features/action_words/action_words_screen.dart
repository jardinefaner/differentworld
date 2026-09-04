import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/mood.dart';
import 'package:differentworld/features/action_words/reveal_overlay.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/widgets/verb_grid.dart';
import 'package:differentworld/features/action_words/widgets/verb_lens_strip.dart';
import 'package:differentworld/features/action_words/widgets/world_badge.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/overflow_actions.dart';
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
    // Warms the space-wide picks so the shared closing action has data here
    // too, and lets us hide "Reveal all" when nobody has picked yet (no more
    // tapping into an empty ceremony).
    final revealItems = ref.watch(todaysRevealItemsProvider);
    return EdgeScaffold(
      actions: [
        OverflowActions([
          // The gold "Reveal all" keeps its tint inline AND in the menu
          // (iconColor) — the colour is the signal that it's the
          // celebratory verb.
          if (revealItems.isNotEmpty)
            EdgeAction(
              icon: Icons.auto_awesome_motion,
              label: 'Reveal all',
              iconColor: WorldBadge.goldFor(Theme.of(context)),
              onPressed: () => unawaited(revealAllPicksToday(context, ref)),
            ),
          // Cast the room's picks to the wall — the calm projection (one slide
          // per child: their world + three verbs), the same present engine
          // every other deck rides. Distinct from "Reveal all" (the dramatic
          // tap-to-advance ceremony); this is the steady recap.
          if (revealItems.isNotEmpty)
            EdgeAction(
              icon: Icons.cast,
              label: 'Cast to room',
              onPressed: () => unawaited(castTodaysWordsToRoom(context, ref)),
            ),
          EdgeAction(
            icon: Icons.menu_book_outlined,
            label: 'Our worlds',
            onPressed: () => context.push('/action-words/worlds'),
          ),
          EdgeAction(
            icon: Icons.outgoing_mail,
            label: 'Send home',
            onPressed: () => context.push('/action-words/send'),
          ),
        ]),
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
              message:
                  'Add children to your program, then pick each one’s '
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
                        'The 10-week journey',
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

/// Which child's inline verb-picker is open — one at a time. Replaces the
/// per-kid bottom sheet (CLAUDE.md "No modal is a task"): tap a row and the
/// pick + mood + their-world reveal unfold in place.
class _ExpandedPick extends Notifier<String?> {
  @override
  String? build() => null;

  /// Open this row, or close it if it's already the open one (one at a time).
  void toggle(String id) => state = state == id ? null : id;
}

final _expandedPickProvider = NotifierProvider<_ExpandedPick, String?>(
  _ExpandedPick.new,
);

class _KidRow extends ConsumerWidget {
  const _KidRow({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref
        .watch(
          actionWordsForDayProvider(
            (subjectId: subject.id, date: todayKey()),
          ),
        )
        .value;
    final picks = day?.verbPicks ?? const <String>[];
    final hasPicks = day?.hasPicks ?? false;
    final match = (day?.hasPicks ?? false)
        ? resolveWorld(
            day!.verbPicks.toSet(),
            ref.watch(classWorldBookProvider),
          )
        : null;
    final fullName = '${subject.firstName} ${subject.lastName}'.trim();
    final expanded = ref.watch(_expandedPickProvider) == subject.id;

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            // Tap unfolds the pick in place — no modal (CLAUDE.md "No modal
            // is a task"). One row open at a time.
            onTap: () =>
                ref.read(_expandedPickProvider.notifier).toggle(subject.id),
            // Long-press → the child's world collection over time.
            onLongPress: () => context.push('/action-words/${subject.id}'),
            leading: _Leading(match: match),
            title: Text(
              fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hand the device to the child to pick their own three words.
                IconButton(
                  tooltip: 'Let ${subject.firstName} pick',
                  icon: const Icon(Icons.front_hand_outlined),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  onPressed: () => unawaited(
                    context.push('/action-words/pick/${subject.id}'),
                  ),
                ),
                if (hasPicks) ...[
                  _Dots(done: day!.doneCount, total: kPicksPerDay),
                  // Role-4: hand the device to the child to DO their verb-jobs.
                  IconButton(
                    tooltip: 'Hand ${subject.firstName} their jobs',
                    icon: const Icon(Icons.assignment_turned_in_outlined),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => unawaited(
                      context.push('/action-words/job/${subject.id}'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Reveal ${subject.firstName}’s world',
                    icon: const Icon(Icons.auto_awesome),
                    color: WorldBadge.goldFor(theme),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => RevealOverlay.show(
                      context,
                      subject: subject,
                      day: day,
                    ),
                  ),
                ] else
                  Icon(expanded ? Icons.expand_less : Icons.chevron_right),
              ],
            ),
          ),
          // The pick unfolds here when this row is the open one.
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? _InlinePicker(
                    key: ValueKey('inline-pick-${subject.id}'),
                    subject: subject,
                    initial: picks,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
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

class _InlinePicker extends ConsumerStatefulWidget {
  const _InlinePicker({
    required this.subject,
    required this.initial,
    super.key,
  });

  final Subject subject;
  final List<String> initial;

  @override
  ConsumerState<_InlinePicker> createState() => _InlinePickerState();
}

class _InlinePickerState extends ConsumerState<_InlinePicker> {
  // Mount-time init from the day's saved picks. Collapsing unmounts
  // _InlinePicker, so the State is created fresh on every expand — this
  // re-reads the current picks each open, and a remote sync landing mid-pick
  // won't clobber the in-progress local selection.
  late final Set<String> _selected = widget.initial.toSet();
  bool _saving = false;

  void _toggle(String id) {
    setState(() {
      if (!_selected.remove(id) && _selected.length < kPicksPerDay) {
        _selected.add(id);
      }
    });
    // Auto-save the moment the third word lands — the pick IS the commit, no
    // Save button. Stays open to show their world; collapses on the next tap.
    if (_selected.length == kPicksPerDay) unawaited(_save());
  }

  Future<void> _save() async {
    if (_saving || _selected.length != kPicksPerDay) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _saving = true);
    await ref
        .read(actionWordsActionsProvider)
        .setPicks(
          subjectId: widget.subject.id,
          groupId: widget.subject.groupId,
          date: todayKey(),
          verbIds: _selected.toList(),
        );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = _selected.length == kPicksPerDay;
    final match = ready
        ? resolveWorld(_selected, ref.watch(classWorldBookProvider))
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_saving)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Text(
                ready
                    ? 'Saved · their world today'
                    : 'Tap 3 words (${_selected.length}/$kPicksPerDay)',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              // The visible collapse control — tapping the row header also
              // closes it, but once picks are saved the header fills with
              // action icons, so this keeps "close" discoverable.
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.expand_less),
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(_expandedPickProvider.notifier)
                    .toggle(widget.subject.id),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Mood Weather, inline — the morning check rides the same gesture
          // as the verb pick (no separate per-kid nav).
          _PickMoodRow(
            subjectId: widget.subject.id,
            groupId: widget.subject.groupId,
          ),
          const SizedBox(height: 12),
          VerbGrid(selected: _selected, onToggle: _toggle),
          if (match != null) ...[
            const SizedBox(height: 18),
            WorldBadge(match: match, showVerbs: false, emojiSize: 52),
            const SizedBox(height: 14),
            // THE LENS — how this kid will do today's shared activity.
            Text(
              'Their way today',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Center(child: VerbLensStrip(verbIds: _selected.toList())),
            // YOUR RULE THIS WEEK — of the world's three rules, the one their
            // verbs claim (docs/WORLD.md).
            if (ref.watch(currentWorldProvider) case final cw?)
              if (ruleForVerbs(cw.id, _selected) case final rule?) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Their rule this week',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer
                              .withValues(alpha: 0.7),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        rule.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                onPressed: () => unawaited(
                  context.push(
                    '/action-words/activities?verbs=${_selected.join(',')}',
                  ),
                ),
                icon: const Icon(Icons.local_activity_outlined, size: 18),
                label: const Text('See matching activities'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The inline Mood Weather strip on the verb-pick sheet — five tappable
/// emoji; today's pick is highlighted. Collapses the morning mood check into
/// the same per-kid sheet as the verb pick (the operational red-team's
/// Blocker 1: no more 3-navigation-deep per-child mood flow).
class _PickMoodRow extends ConsumerWidget {
  const _PickMoodRow({required this.subjectId, this.groupId});

  final String subjectId;
  final String? groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = watchTodayMood(ref, subjectId)?.level;
    return Row(
      children: [
        for (final m in MoodLevel.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => unawaited(
                  ref
                      .read(entryActionsProvider)
                      .recordMood(
                        subjectId: subjectId,
                        value: m.value,
                        groupId: groupId,
                      ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: today == m
                        ? m.color.withValues(alpha: 0.30)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: today == m
                        ? Border.all(color: m.color, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(m.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cast the room's picks to the wall — a calm slide deck (lead card + one
/// slide per child: their world emoji/name + the three verbs they chose),
/// presented through the same generic present engine every deck rides
/// (docs/VISION.md 2026-06-20 — anything can become slides). The in-room
/// projection, NOT a sent-home artifact: every name shown belongs to a child
/// present in the room (same as the reveal ceremony), so no other-name scrub
/// is needed. Reads the space-wide [todaysRevealItemsProvider]; a gentle nudge
/// instead of an empty deck when nobody's picked yet.
Future<void> castTodaysWordsToRoom(BuildContext context, WidgetRef ref) {
  final items = ref.read(todaysRevealItemsProvider);
  if (items.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('No words to cast yet — pick today’s words first.'),
      ),
    );
    return Future<void>.value();
  }
  final slides = <PresentSlide>[
    PresentSlide(
      eyebrow: 'Today in our room',
      title: 'Today’s words',
      emoji: '🌍',
      subtitle: items.length == 1
          ? '1 explorer chose their words'
          : '${items.length} explorers chose their words',
    ),
  ];
  for (final it in items) {
    final world = it.day.world?.world;
    final verbs = verbsByIds(it.day.verbPicks);
    slides.add(
      PresentSlide(
        eyebrow: '${it.subject.firstName} is',
        title: world?.name ?? it.day.worldName ?? 'A brand-new world',
        emoji: world?.emoji ?? '✨',
        subtitle: verbs.map((v) => v.label).join('  ·  '),
      ),
    );
  }
  return presentSlides(context, title: 'Today’s words', slides: slides);
}
