import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/journey_day_sheet.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worksheet_pdf.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/this-week` — the live hub for the curriculum week. Shows the world the
/// room is in RIGHT NOW (derived from the program start date), its featured
/// verbs, today's Watch → Do videos, and the activities — plus the actions
/// that make it real in the room: project it (Cast), print the worksheets,
/// and jump to the matched activities. The director sets up / moves the
/// 10-week journey here.
class ThisWeekScreen extends ConsumerWidget {
  const ThisWeekScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worldsLoading = ref.watch(curriculumWorldsProvider).isLoading;
    final world = ref.watch(currentWorldProvider);
    final viewer = ref.watch(viewerProvider);

    return EdgeScaffold(
      actions: [
        if (viewer.isDirector && world != null)
          IconButton(
            tooltip: 'Manage journey',
            icon: const Icon(Icons.tune),
            onPressed: () => _manage(context, ref, viewer.spaceId),
          ),
      ],
      body: worldsLoading
          ? const LoadingSlot()
          : world == null
          ? _NotLive(
              isDirector: viewer.isDirector,
              onSetup: viewer.spaceId == null
                  ? null
                  : () => _manage(context, ref, viewer.spaceId),
            )
          : _LiveWorld(world: world),
    );
  }

  Future<void> _manage(BuildContext context, WidgetRef ref, String? spaceId) {
    if (spaceId == null) return Future.value();
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _JourneySheet(spaceId: spaceId),
    );
  }
}

/// This weekly world's five authored days, as a tappable list with today
/// badged. Renders nothing until the journey is active + worlds have loaded.
class _FortnightSection extends ConsumerWidget {
  const _FortnightSection({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final block = ref.watch(currentBlockProvider);
    final today = ref.watch(currentProgramDayProvider);
    if (block == null || block.days.isEmpty) return const SizedBox.shrink();
    return Column(
      // Shrink-wrap for the bento cell (min-height / unbounded-max).
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: 'This week, day by day', accent: accent),
        for (var i = 0; i < block.days.length; i++)
          JourneyDayRow(
            day: block.days[i].day,
            journeyDay: block.days[i],
            block: block,
            wallQuestion: i < block.wallQuestions.length
                ? block.wallQuestions[i]
                : null,
            isToday: block.days[i].day == today,
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _LiveWorld extends ConsumerWidget {
  const _LiveWorld({required this.world});
  final CurriculumWorld world;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = world.color;
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the SAME sections (hero / actions /
    // day-by-day / verbs / rules / watch→do / big thinking / activities)
    // re-lay as importance-weighted bento tiles instead of one tall scroll.
    // Every section is built from the same closures below, so the two layouts
    // never drift; all behaviour (cast, play, add-rule, navigation) is shared.
    final bento = bentoEnabled(ref, perScreen: null);

    // ----- Section content, shared by both layouts -----------------------
    // Each returns a shrink-wrapping widget so it's safe in a bento cell
    // (min-height / unbounded-max → no Expanded/Spacer; docs/GRID.md).
    final hero = _Hero(world: world, accent: accent);
    final actions = _ActionsRow(world: world, accent: accent);
    final fortnight = _FortnightSection(accent: accent);
    final verbs = _VerbsSection(world: world, accent: accent);
    final rules = _RulesSection(world: world, accent: accent);
    final watchDo = world.videos.isEmpty
        ? null
        : _WatchDoSection(world: world, accent: accent);
    // This world's Big Thinking game(s) — play → name → bridge → question.
    final thinking = thinkingGamesForWeek(
      ref.watch(thinkingGamesProvider).value ?? const [],
      world.week,
    );
    final bigThinking = thinking.isEmpty
        ? null
        : _BigThinkingSection(games: thinking, accent: accent);
    final activities = _ActivitiesSection(world: world, accent: accent);

    if (bento) {
      // Hero leads (the "what world are we in" identity): full on phone,
      // two-thirds on desktop, two rows tall. Actions pairs beside it to fill
      // the top desktop run. The content sections are text/list-shaped and
      // read best full-width, so they're wide banners below — which also keeps
      // the 1-D Wrap packing into clean runs (no ragged gaps).
      return ResponsivePage(
        children: [
          const ContentHeader(
            title: 'This week’s world',
            subtitle: 'The world the room is living in right now',
          ),
          const SizedBox(height: 12),
          BentoGrid(
            tiles: [
              BentoTile(id: 'hero', span: const BentoSpan.hero(), child: hero),
              BentoTile(
                id: 'actions',
                span: const BentoSpan(tablet: 4, rows: 2),
                child: actions,
              ),
              // _FortnightSection renders nothing until the journey is active;
              // when empty the tile is a min-height empty box, which the Wrap
              // packs harmlessly — keeping the section's own gating intact.
              BentoTile(
                id: 'fortnight',
                span: const BentoSpan.wide(),
                child: fortnight,
              ),
              BentoTile(
                id: 'verbs',
                span: const BentoSpan.wide(),
                child: verbs,
              ),
              BentoTile(
                id: 'rules',
                span: const BentoSpan.wide(),
                child: rules,
              ),
              if (watchDo != null)
                BentoTile(
                  id: 'watch-do',
                  span: const BentoSpan.wide(),
                  child: watchDo,
                ),
              if (bigThinking != null)
                BentoTile(
                  id: 'big-thinking',
                  span: const BentoSpan.wide(),
                  child: bigThinking,
                ),
              BentoTile(
                id: 'activities',
                span: const BentoSpan.wide(),
                child: activities,
              ),
            ],
          ),
        ],
      );
    }

    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'This week’s world',
          subtitle: 'The world the room is living in right now',
        ),
        hero,
        const SizedBox(height: 16),
        actions,
        const SizedBox(height: 20),
        // This week, day by day — the weekly world's five authored days. Tap
        // any day to read its full focus + wall question + room; today is
        // badged. Lets staff prep ahead, not just see today (renders nothing
        // until the worlds load).
        fortnight,
        verbs,
        const SizedBox(height: 20),
        rules,
        const SizedBox(height: 20),
        if (watchDo != null) ...[watchDo, const SizedBox(height: 20)],
        if (bigThinking != null) ...[bigThinking, const SizedBox(height: 20)],
        activities,
      ],
    );
  }
}

/// The world identity hero — emoji, week, name, the world's question.
class _Hero extends StatelessWidget {
  const _Hero({required this.world, required this.accent});
  final CurriculumWorld world;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(world.emoji, style: const TextStyle(fontSize: 60)),
          const SizedBox(height: 6),
          Text(
            'Week ${world.week}',
            style: theme.textTheme.labelMedium?.copyWith(color: accent),
          ),
          Text(
            world.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '“${world.question}”',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// The lead actions — Play today + Cast + More. Wraps, so it shrink-wraps in
/// a bento cell.
class _ActionsRow extends StatelessWidget {
  const _ActionsRow({required this.world, required this.accent});
  final CurriculumWorld world;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed: () => context.push('/play-today'),
          icon: const Icon(Icons.play_circle_fill),
          label: const Text('Play today'),
        ),
        OutlinedButton.icon(
          onPressed: () => _castOptions(context, world),
          icon: const Icon(Icons.cast),
          label: const Text('Cast to the room'),
        ),
        // The 6 secondary verbs were a wall of co-equal buttons (this-week
        // was 🔴, 8 equal CTAs — docs/CLARITY_RUBRIC.md). Now one "More"
        // opens them in a sheet so Play today + Cast clearly lead.
        OutlinedButton.icon(
          onPressed: () => _moreActions(context, world),
          icon: const Icon(Icons.more_horiz),
          label: const Text('More'),
        ),
      ],
    );
  }
}

/// This week's featured verbs as compact chips, under a label.
class _VerbsSection extends StatelessWidget {
  const _VerbsSection({required this.world, required this.accent});
  final CurriculumWorld world;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: 'This week’s verbs', accent: accent),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in world.featuredVerbs)
              if (verbById(id) case final v?)
                EntityChipTap(
                  entity: EntityRef(
                    kind: EntityKind.verb,
                    id: v.id,
                    label: v.label,
                  ),
                  child: Chip(
                    label: Text('${v.emoji} ${v.label}'),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

/// The world's bible — authored rules + any the room added, plus "Add a rule".
class _RulesSection extends ConsumerWidget {
  const _RulesSection({required this.world, required this.accent});
  final CurriculumWorld world;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The world's rules — the authored ones (every kid hears all three;
        // their verbs decide which is theirs) PLUS any the ROOM added (the
        // "add a rule" mechanic; docs/VISION.md). The bible is extensible.
        _Label(text: 'The rules of this world', accent: accent),
        for (final rule in rulesForWorld(world.id))
          _RuleLine(text: rule.text, accent: accent),
        for (final rule in ref.watch(addedWorldRulesProvider(world.id)).value ??
            const <({String id, String text})>[])
          _RuleLine(
            text: rule.text,
            accent: accent,
            added: true,
            onDelete: () => unawaited(_deleteAddedRule(context, ref, rule.id)),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () =>
                unawaited(_showAddRuleSheet(context, ref, world.id)),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add a rule'),
          ),
        ),
      ],
    );
  }
}

/// Today's Watch → Do videos + the screen-time guidance line.
class _WatchDoSection extends StatelessWidget {
  const _WatchDoSection({required this.world, required this.accent});
  final CurriculumWorld world;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: 'Watch → Do', accent: accent),
        for (final v in world.videos)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.play_circle_outline, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${v.title}  ·  ${v.minutes} min',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '→ ${v.after}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          kScreenTimeRules.first,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// This world's Big Thinking game(s) — play → name → bridge → question.
class _BigThinkingSection extends StatelessWidget {
  const _BigThinkingSection({required this.games, required this.accent});
  final List<ThinkingGame> games;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: 'Big thinking', accent: accent),
        for (final g in games)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => unawaited(context.push('/thinking')),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${g.emoji}  ', style: const TextStyle(fontSize: 18)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.concept,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          g.meaning,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The world's activities, as a bulleted list under a label.
class _ActivitiesSection extends StatelessWidget {
  const _ActivitiesSection({required this.world, required this.accent});
  final CurriculumWorld world;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(text: 'Activities', accent: accent),
        for (final a in world.activities)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: TextStyle(color: accent, height: 1.4)),
                Expanded(child: Text(a, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// Cast this world to the room — the shared mirror-vs-paired chooser.
Future<void> _castOptions(BuildContext context, CurriculumWorld world) {
  return showCastToRoom(
    context,
    mirrorRoute: '/present-world/${world.id}',
    mirrorLabel: 'Mirror to this screen',
    mirrorSubtitle: 'Show it right here — for a projector by cable or AirPlay.',
  );
}

/// The secondary world verbs, moved off the action row into a sheet so the
/// row leads with Play today + Cast (docs/CLARITY_RUBRIC.md).
Future<void> _moreActions(BuildContext context, CurriculumWorld world) {
  void go(String route) {
    Navigator.of(context).pop();
    unawaited(context.push(route));
  }

  return showGlassSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.local_activity_outlined),
            title: const Text('Activities'),
            onTap: () => go(
              '/action-words/activities?verbs=${world.featuredVerbs.join(',')}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.casino_outlined),
            title: const Text('Make one'),
            onTap: () => go('/forge'),
          ),
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text('Worksheets'),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(printWorldWorksheets(world));
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: const Text('The Wall'),
            onTap: () => go('/wall'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_clock_outlined),
            title: const Text('Time capsules'),
            onTap: () => go('/time-capsules'),
          ),
          ListTile(
            leading: const Icon(Icons.public_outlined),
            title: const Text('Explore all worlds'),
            onTap: () => go('/action-words/different-worlds'),
          ),
        ],
      ),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.accent});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: accent, letterSpacing: 0.4),
      ),
    );
  }
}

class _NotLive extends StatelessWidget {
  const _NotLive({required this.isDirector, required this.onSetup});
  final bool isDirector;
  final VoidCallback? onSetup;

  @override
  Widget build(BuildContext context) {
    if (!isDirector) {
      return const EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'The journey hasn’t started',
        message:
            'Once your director sets the start date, this week’s world '
            'shows up here.',
      );
    }
    return EmptyState(
      icon: Icons.rocket_launch_outlined,
      title: 'Start the 10-week journey',
      message:
          'Set the week your program begins (or jump to the week you’re '
          'on now). The live world appears here and on Today.',
      action: FilledButton.icon(
        onPressed: onSetup,
        icon: const Icon(Icons.rocket_launch),
        label: const Text('Set up the journey'),
      ),
    );
  }
}

/// Director sheet: pick the start date, jump to a week, or clear.
class _JourneySheet extends ConsumerWidget {
  const _JourneySheet({required this.spaceId});
  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final worlds = ref.watch(curriculumWorldsProvider).value ?? const [];
    final liveWeek = ref.watch(currentCurriculumWeekProvider);

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  'The 10-week journey',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'Pick the week you’re on now — it keeps advancing on its own.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final w in worlds)
                ListTile(
                  leading: Text(w.emoji, style: const TextStyle(fontSize: 26)),
                  title: Text('Week ${w.week} · ${w.name}'),
                  trailing: w.week == liveWeek
                      ? Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    final nav = Navigator.of(context);
                    await ref
                        .read(worldScheduleActionsProvider)
                        .jumpToWeek(spaceId, w.week);
                    nav.pop();
                  },
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.event),
                title: const Text('Set an exact start date'),
                onTap: () async {
                  final nav = Navigator.of(context);
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 1),
                    helpText: 'Week 1 begins',
                  );
                  if (picked == null) return;
                  await ref
                      .read(worldScheduleActionsProvider)
                      .setStartDate(spaceId, picked);
                  nav.pop();
                },
              ),
              if (liveWeek != null)
                ListTile(
                  leading: Icon(Icons.clear, color: theme.colorScheme.error),
                  title: Text(
                    'Clear the journey',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  onTap: () async {
                    final nav = Navigator.of(context);
                    await ref.read(worldScheduleActionsProvider).clear(spaceId);
                    nav.pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One rule line in the world bible. Authored rules are marked `•` (canon);
/// a rule the ROOM added gets a `+` + a quiet "your room" tag, so the bible
/// visibly distinguishes the curriculum's rules from the class's own.
class _RuleLine extends StatelessWidget {
  const _RuleLine({
    required this.text,
    required this.accent,
    this.added = false,
    this.onDelete,
  });

  final String text;
  final Color accent;
  final bool added;

  /// Delete handler. Only room-added rules pass one; authored (canon) rules
  /// leave it null and stay undeletable — the world's own rules are premise.
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(added ? '+  ' : '•  ',
              style: TextStyle(color: accent, height: 1.4)),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: added ? FontStyle.italic : null,
              ),
            ),
          ),
          if (added) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                'your room',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Delete this rule',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showAddRuleSheet(
  BuildContext context,
  WidgetRef ref,
  String worldId,
) {
  return showGlassSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _AddRuleSheet(worldId: worldId),
  );
}

/// Delete a rule the ROOM added to a world's bible (confirmed first). Authored
/// canon rules never reach here — only `_RuleLine(added: true)` wires onDelete,
/// so the world's own rules stay immutable premise.
Future<void> _deleteAddedRule(
  BuildContext context,
  WidgetRef ref,
  String id,
) async {
  final ok = await confirmDestructive(
    context,
    title: 'Delete this rule?',
    message: "It'll be removed from this world's bible for your room. "
        "The world's own rules stay.",
  );
  if (!ok) return;
  await ref.read(entryActionsProvider).delete(id);
}

/// The one-field "add a rule" sheet. A short rule the room lives by, written
/// into the world's bible (an `EntryKind.worldRule` entry).
class _AddRuleSheet extends ConsumerStatefulWidget {
  const _AddRuleSheet({required this.worldId});

  final String worldId;

  @override
  ConsumerState<_AddRuleSheet> createState() => _AddRuleSheetState();
}

class _AddRuleSheetState extends ConsumerState<_AddRuleSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    unawaited(HapticFeedback.selectionClick());
    await ref
        .read(entryActionsProvider)
        .addWorldRule(text: text, worldId: widget.worldId);
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a rule', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'A rule your room lives by — it joins this world’s bible.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              maxLength: 200,
              decoration: const InputDecoration(
                hintText: 'e.g. We clean up together',
              ),
              onSubmitted: (_) => unawaited(_save()),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _saving ? null : () => unawaited(_save()),
                child: const Text('Add to the bible'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
