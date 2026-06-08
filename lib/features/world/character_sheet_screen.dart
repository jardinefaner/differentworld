import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/mood.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/week_log.dart';
import 'package:differentworld/features/action_words/widgets/thinking_game_sheet.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/world/character_sheet_providers.dart';
import 'package:differentworld/features/world/skill_measure.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/scale_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/subjects/:id/me` — the **Me** screen: a child's persistent in-world self
/// (Different World; docs/WORLD.md). The drawn avatar + the chosen name. The
/// first window onto the summer-long identity; crew, dream, world, words, and
/// age (= dailies) join it in later slices.
///
/// Reached from the subject's detail screen. Staff-facing for now (the two
/// age surfaces — soft for 4–6, full for 7–12 — come later).
class CharacterSheetScreen extends ConsumerWidget {
  const CharacterSheetScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sheetAsync = ref.watch(characterSheetForSubjectProvider(subjectId));
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    return EdgeScaffold(
      body: SafeArea(
        child: sheetAsync.when(
          loading: () => const LoadingSlot(variant: LoadingVariant.spinner),
          error: (e, _) => ErrorState(
            title: "Couldn't load the world self",
            detail: '$e',
          ),
          data: (sheet) => _Body(
            subjectId: subjectId,
            sheet: sheet,
            subject: subject,
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.subjectId,
    required this.sheet,
    required this.subject,
  });

  final String subjectId;
  final CharacterSheet? sheet;
  final Subject? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstName = subject?.firstName;
    final chosen = sheet?.chosenName;
    final hasName = chosen != null && chosen.trim().isNotEmpty;
    final displayName = hasName ? chosen.trim() : (firstName ?? '?');
    final hasDrawing = sheet?.avatarUrl != null;

    // The rest of the sheet, assembled from data that already exists.
    final collection = ref
        .watch(actionWordsCollectionProvider(subjectId))
        .value;
    final entries =
        ref
            .watch(
              entriesForSubjectProvider(
                (subjectId: subjectId, kind: null),
              ),
            )
            .value ??
        const <Entry>[];
    final week = ref.watch(currentCurriculumWeekProvider);
    final world = ref.watch(currentWorldProvider);
    final start = ref.watch(programStartDateProvider);
    final worlds = ref.watch(curriculumWorldsProvider).value ?? const [];
    final ageDays = _participationDays(entries);
    final visitedWeeks = _visitedWeeks(entries, start);
    final practiced = collection?.verbTotals ?? const <String, int>{};
    final title = collection?.emergingTitle;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            ContentHeader(
              title: 'World self',
              subtitle: firstName != null
                  ? "$firstName's summer identity"
                  : 'Draw and name your world self',
            ),
            const SizedBox(height: 8),
            Center(
              child: PersonAvatar(
                name: displayName,
                photoUrl: sheet?.avatarUrl,
                radius: 76,
                onTap: () =>
                    _goDraw(context, hasName ? chosen.trim() : firstName),
              ),
            ),
            const SizedBox(height: 24),
            // The chosen name (or a prompt to choose one). Intentionally an
            // inline tap-to-edit affordance (not a FeatureCard row) — it's a
            // centred headline, not a list item; the InkWell gives it a 48 dp
            // ripple target.
            Center(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => unawaited(_editName(context, ref, chosen)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            hasName ? chosen.trim() : 'Choose a name',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: hasName
                                  ? null
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // TITLE — emerges from verb patterns ("The Owl Who Listens").
            if (title != null) ...[
              const SizedBox(height: 4),
              Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            // AGE · SEASON · MAP.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _Chip(icon: Icons.cake_outlined, label: 'Day $ageDays'),
                if (week != null)
                  _Chip(
                    icon: Icons.calendar_today_outlined,
                    label: 'Week $week',
                  ),
                if (world != null) _Chip(emoji: world.emoji, label: world.name),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () =>
                    _goDraw(context, hasName ? chosen.trim() : firstName),
                icon: Icon(hasDrawing ? Icons.brush : Icons.brush_outlined),
                label: Text(
                  hasDrawing ? 'Redraw myself' : 'Draw myself',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (!hasDrawing) ...[
              const SizedBox(height: 16),
              Text(
                'Hand the device over and let them draw — their first picture '
                'of themselves becomes their face in the world.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 16),
            _Weather(subjectId: subjectId),
            const SizedBox(height: 22),
            _Section(
              label: 'Abilities · the 12 verbs',
              systemId: 'abilities',
              child: _Verbs(practiced: practiced),
            ),
            const SizedBox(height: 22),
            // Skills — the RPG "stats that grow". The one synthesis piece with
            // new data: the line going up is the proof a brain grew.
            _Skills(
              entries: entries,
              subjectId: subjectId,
              firstName: firstName ?? 'this child',
              groupId: subject?.groupId,
            ),
            const SizedBox(height: 22),
            // Spells — the kid's earned vocabulary, from their weekly logs.
            _Spells(entries: entries),
            const SizedBox(height: 22),
            _Section(
              label: 'Collection · worlds visited',
              systemId: 'collection',
              child: _Worlds(worlds: worlds, visited: visitedWeeks),
            ),
            const SizedBox(height: 22),
            // Quests — the long game made visible (project-length progress).
            _Quests(
              visited: visitedWeeks,
              worldCount: worlds.length,
              days: ageDays,
              week: week,
            ),
            const SizedBox(height: 22),
            // Allies — the party, from the weekly logs (staff-side, full names;
            // export scrubs other-child names — see summer_book).
            _Allies(entries: entries),
            const SizedBox(height: 22),
            _Milestones(entries: entries),
            const SizedBox(height: 22),
            _Links(subjectId: subjectId),
          ],
        ),
      ),
    );
  }

  void _goDraw(BuildContext context, String? greetingName) {
    unawaited(context.push('/subjects/$subjectId/draw', extra: greetingName));
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String? current,
  ) async {
    final controller = TextEditingController(text: current ?? '');
    try {
      final saved = await showDialog<String?>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Choose a name'),
            content: TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 40,
              decoration: const InputDecoration(
                hintText: 'Your world-self name',
              ),
              onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(controller.text),
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
      if (saved == null) return; // cancelled
      await ref
          .read(characterSheetActionsProvider)
          .setChosenName(
            subjectId: subjectId,
            name: saved,
          );
    } finally {
      controller.dispose();
    }
  }

  /// AGE = distinct days the child shows up in any captured moment.
  int _participationDays(List<Entry> entries) {
    final days = <String>{};
    for (final e in entries) {
      final local = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (local != null) days.add(dateKey(local));
    }
    return days.length;
  }

  Set<int> _visitedWeeks(List<Entry> entries, DateTime? start) {
    final weeks = <int>{};
    if (start == null) return weeks;
    for (final e in entries) {
      final local = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (local == null) continue;
      final w = curriculumWeekFor(start, local);
      if (w != null) weeks.add(w);
    }
    return weeks;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.icon, this.emoji});
  final String label;
  final IconData? icon;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text('$emoji ')
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(icon, size: 15),
            ),
          Text(label, style: theme.textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child, this.systemId});
  final String label;
  final Widget child;

  /// If set, an RPG system id — a "the game under this" link appears under
  /// the section, opening that system's Big Thinking game.
  final String? systemId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 10),
        child,
        if (systemId != null) _SystemGameLink(systemId: systemId!),
      ],
    );
  }
}

/// "✦ The game under this · CONCEPT" — opens the Big Thinking game that sits
/// beneath an RPG system. Hidden if the deck has no game for that system.
class _SystemGameLink extends ConsumerWidget {
  const _SystemGameLink({required this.systemId});
  final String systemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(systemThinkingGameProvider(systemId));
    if (game == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => unawaited(showThinkingGameSheet(context, game)),
        icon: const Icon(Icons.auto_awesome_outlined, size: 16),
        label: Text('The game under this · ${game.concept}'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          textStyle: Theme.of(context).textTheme.labelMedium,
        ),
      ),
    );
  }
}

class _Weather extends ConsumerWidget {
  const _Weather({required this.subjectId});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moodEntries =
        ref
            .watch(
              entriesForSubjectProvider(
                (subjectId: subjectId, kind: EntryKind.mood),
              ),
            )
            .value ??
        const <Entry>[];

    final todayKeyStr = dateKey(DateTime.now());
    MoodReading? today;
    for (final e in moodEntries) {
      final local = DateTime.tryParse(e.recordedAt)?.toLocal();
      if (local != null && dateKey(local) == todayKeyStr) {
        today = MoodReading.fromEntry(e);
        break; // newest-first → first match is the latest today
      }
    }
    final log = moodReadings(moodEntries).take(14).toList().reversed.toList();

    return _Section(
      label: 'Weather · today’s mood',
      systemId: 'weather',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final m in MoodLevel.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => unawaited(
                        ref
                            .read(entryActionsProvider)
                            .recordMood(
                              subjectId: subjectId,
                              value: m.value,
                            ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: today?.level == m
                              ? m.color.withValues(alpha: 0.30)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          border: today?.level == m
                              ? Border.all(color: m.color, width: 2)
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(m.emoji, style: const TextStyle(fontSize: 24)),
                            Text(
                              '${m.value}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (log.length > 1) ...[
            const SizedBox(height: 12),
            Text(
              'Weather log',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              children: [
                for (final r in log)
                  Text(r.level.emoji, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Verbs extends StatelessWidget {
  const _Verbs({required this.practiced});
  final Map<String, int> practiced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in kVerbs)
          if (practiced[v.id] case final n? when n > 0)
            Chip(
              avatar: Text(v.emoji),
              label: Text('${v.label} ·$n'),
              visualDensity: VisualDensity.compact,
            )
          else
            // BLIND SPOT — a verb never practiced, an invitation.
            Opacity(
              opacity: 0.4,
              child: Chip(
                avatar: Text(v.emoji),
                label: Text(v.label),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
      ],
    );
  }
}

class _Worlds extends StatelessWidget {
  const _Worlds({required this.worlds, required this.visited});
  final List<CurriculumWorld> worlds;
  final Set<int> visited;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 520 ? 5 : 4;
        return GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.82,
          children: [
            for (final w in worlds)
              Opacity(
                opacity: visited.contains(w.week) ? 1 : 0.3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(w.emoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(height: 2),
                    Text(
                      'Wk ${w.week}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Milestones extends StatelessWidget {
  const _Milestones({required this.entries});
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moments = momentsFrom(
      entries.where((e) => e.kind == EntryKind.observation).toList(),
    ).take(4).toList();
    if (moments.isEmpty) return const SizedBox.shrink();
    return _Section(
      label: 'Milestones · what the room noticed',
      child: Column(
        children: [
          for (final m in moments)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      (m.body?.trim().isNotEmpty ?? false) ? m.body! : m.title,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links({required this.subjectId});
  final String subjectId;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        OutlinedButton.icon(
          onPressed: () => unawaited(context.push('/book/$subjectId')),
          icon: const Icon(Icons.auto_stories_outlined),
          label: const Text('Home base · the book'),
        ),
        OutlinedButton.icon(
          onPressed: () => unawaited(context.push('/action-words/$subjectId')),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Worlds revealed'),
        ),
        OutlinedButton.icon(
          onPressed: () => unawaited(context.push('/wall')),
          icon: const Icon(Icons.dashboard_customize_outlined),
          label: const Text('Lore · the wall'),
        ),
      ],
    );
  }
}

/// SKILLS — measured stats that grow. The latest value + the delta from the
/// one before it (the line going up). A "log a measurement" affordance feeds
/// the only new data layer the synthesis needed.
class _Skills extends StatelessWidget {
  const _Skills({
    required this.entries,
    required this.subjectId,
    required this.firstName,
    required this.groupId,
  });

  final List<Entry> entries;
  final String subjectId;
  final String firstName;
  final String? groupId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = latestSkillValues(entries);
    return _Section(
      label: 'Skills · stats that grow',
      systemId: 'skills',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (progress.isEmpty)
            Text(
              "Not measured yet. Skills aren't taught — they're noticed, "
              'inside the activities that already happen.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final skill in kMeasurableSkills)
              if (progress[skill.id] case final p?)
                _SkillRow(skill: skill, progress: p),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => unawaited(
                showSkillMeasureSheet(
                  context,
                  subjectId: subjectId,
                  firstName: firstName,
                  groupId: groupId,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log a measurement'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({required this.skill, required this.progress});
  final MeasurableSkill skill;
  final SkillProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prev = progress.previous;
    final delta = prev == null ? null : progress.latest - prev;
    final up = delta != null && delta > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(skill.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(skill.label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            skill.format(progress.latest),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (delta != null && delta != 0) ...[
            const SizedBox(width: 8),
            Text(
              '${up ? '▲' : '▼'} ${up ? '+' : ''}'
              '${delta % 1 == 0 ? delta.toInt() : delta}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: up
                    ? const Color(0xFF51CF66)
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// SPELLS — the kid's earned vocabulary, gathered from their weekly logs.
class _Spells extends StatelessWidget {
  const _Spells({required this.entries});
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spells = <String>[];
    for (final e in entries) {
      if (e.kind != EntryKind.weekLog) continue;
      final s = WeekLog.fromEntry(e).spell.trim();
      if (s.isNotEmpty && !spells.contains(s)) spells.add(s);
    }
    return _Section(
      label: 'Spells · words earned',
      systemId: 'spells',
      child: spells.isEmpty
          ? Text(
              'No spells learned yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in spells)
                  Chip(
                    label: Text(s),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
    );
  }
}

/// ALLIES — the party, gathered from the weekly logs. Staff-side, full names
/// (the export path scrubs other-child names; this view is canSeeSubject-gated).
class _Allies extends StatelessWidget {
  const _Allies({required this.entries});
  final List<Entry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allies = <String>[];
    for (final e in entries) {
      if (e.kind != EntryKind.weekLog) continue;
      final a = WeekLog.fromEntry(e).ally.trim();
      if (a.isNotEmpty && !allies.contains(a)) allies.add(a);
    }
    return _Section(
      label: 'Allies · the party',
      systemId: 'allies',
      child: allies.isEmpty
          ? Text(
              'No allies logged yet.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in allies)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('🤝  ', style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(a, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// QUESTS — the long game made visible: the project-length goals (visit every
/// world, the days accumulating). The daily quest is the verb pick itself.
class _Quests extends StatelessWidget {
  const _Quests({
    required this.visited,
    required this.worldCount,
    required this.days,
    required this.week,
  });

  final Set<int> visited;
  final int worldCount;
  final int days;
  final int? week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      label: 'Quests · the long game',
      systemId: 'quests',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // COLLECTION as a SCALE — the grid's fill, a position on a continuum.
          ScaleBar(
            label: 'Worlds visited',
            trailing: '${visited.length} / $worldCount',
            scale: Scale(
              value: visited.length,
              max: worldCount == 0 ? 1 : worldCount,
            ),
          ),
          if (week != null) ...[
            const SizedBox(height: 14),
            // LEVEL as a SCALE — Day-1-to-50 in 10-week clothing.
            ScaleBar(
              label: 'The journey',
              trailing: 'Week $week of 10',
              scale: Scale(value: week!, max: 10),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Days here', style: theme.textTheme.bodyMedium),
              ),
              Text(
                '$days',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Daily quest: pick and do your three verbs.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
