part of 'character_sheet_screen.dart';

// The character-sheet SECTIONS — the private section widgets composed by
// _Body. Split out of character_sheet_screen.dart (was 1204 lines) via a
// 'part of' so they stay private with zero call-site changes. Edit the two
// files as one unit.

/// The chosen crew — a tappable chip showing the picked archetype (or a
/// prompt to pick one). The single CHOSEN element of an otherwise earned
/// identity. Closed catalog (crews.dart); no rarity, fully reachable.
class _Crew extends ConsumerWidget {
  const _Crew({required this.subject, required this.subjectId});

  final Subject? subject;
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final crew = crewById(subject?.caps.getString(SubjectCaps.crew));
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => unawaited(_pick(context, ref)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    crew?.emoji ?? '➕',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    crew == null ? 'Pick a crew' : 'Crew · ${crew.name}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: crew == null
                          ? theme.colorScheme.onSurfaceVariant
                          : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final current = subject?.caps.getString(SubjectCaps.crew);
    final picked = await showGlassSheet<String>(
      context: context,
      builder: (_) => _CrewSheet(currentId: current),
    );
    if (picked == null) return; // dismissed
    await ref
        .read(subjectCapActionsProvider)
        .setStringCap(
          subjectId,
          SubjectCaps.crew,
          picked.isEmpty ? null : picked, // '' = clear
        );
  }
}

class _CrewSheet extends StatelessWidget {
  const _CrewSheet({this.currentId});

  final String? currentId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                child: Text('Pick a crew', style: theme.textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'The one thing you choose — the rest of your world self is '
                  'earned.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final c in kCrews)
                ListTile(
                  leading: Text(c.emoji, style: const TextStyle(fontSize: 26)),
                  title: Text(c.name),
                  subtitle: Text(c.blurb),
                  trailing: c.id == currentId
                      ? Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(context).pop(c.id),
                ),
              if (currentId != null)
                ListTile(
                  leading: Icon(Icons.clear, color: theme.colorScheme.error),
                  title: Text(
                    'No crew',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () => Navigator.of(context).pop(''),
                ),
            ],
          ),
        ),
      ),
    );
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
            EntityChipTap(
              entity: EntityRef(
                kind: EntityKind.verb,
                id: v.id,
                label: v.label,
              ),
              child: Chip(
                avatar: Text(v.emoji),
                label: Text('${v.label} ·$n'),
                visualDensity: VisualDensity.compact,
              ),
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
              EntityChipTap(
                entity: EntityRef(
                  kind: EntityKind.world,
                  id: w.id,
                  label: w.name,
                ),
                child: Opacity(
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
                    child: LinkifiedText(
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

/// This world's RPG stage — guidance for where the summer-long character arc is
/// right now: how the avatar evolves this world, the spells to earn, the tools
/// that unlock, and how inventory / allies / lore / weather deepen. Reads the
/// per-world arc (world_arc.json). Renders nothing until the journey is active.
class _WorldStage extends ConsumerWidget {
  const _WorldStage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arc = ref.watch(currentWorldArcProvider);
    if (arc == null) return const SizedBox.shrink();
    final world = ref.watch(currentWorldProvider);
    final rpg = arc.rpg;
    final rows = <(String, String)>[
      ('🎨 Avatar', rpg.avatar),
      ('📛 Name · title', rpg.name),
      ('✨ Spells', rpg.spells),
      ('🔧 Tools', rpg.tools),
      ('🎒 Inventory', rpg.inventory),
      ('🤝 Allies', rpg.allies),
      ('📜 Lore', rpg.lore),
      ('🌤 Weather', rpg.weather),
    ];
    return Column(
      children: [
        _Section(
          label: world != null
              ? 'This world · ${world.name}'
              : 'This world’s stage',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, text) in rows)
                if (text.isNotEmpty) _StageRow(label: label, text: text),
            ],
          ),
        ),
        const SizedBox(height: 22),
      ],
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
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
        FilledButton.icon(
          onPressed: () => unawaited(context.push('/subjects/$subjectId/day')),
          icon: const Icon(Icons.today_outlined),
          label: const Text('Today'),
        ),
        OutlinedButton.icon(
          onPressed: () => unawaited(context.push('/growth/$subjectId')),
          icon: const Icon(Icons.play_circle_outline),
          label: const Text('Play their story'),
        ),
        OutlinedButton.icon(
          onPressed: () => unawaited(
            showCastToRoom(
              context,
              mirrorRoute: '/growth/$subjectId',
              mirrorSubtitle:
                  'Open their story here, then mirror to the TV — great at '
                  'pickup. Tap auto-advance to let it play itself.',
            ),
          ),
          icon: const Icon(Icons.cast),
          label: const Text('Cast their story'),
        ),
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
                // Theme-aware (not a magic green that clashes on warm
                // surfaces / dark mode); the ▲/▼ already encodes direction.
                color: up
                    ? theme.colorScheme.primary
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
                          child: LinkifiedText(a,
                              style: theme.textTheme.bodyMedium),
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
