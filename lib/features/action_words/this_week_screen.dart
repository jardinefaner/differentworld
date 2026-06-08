import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worksheet_pdf.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
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

class _LiveWorld extends ConsumerWidget {
  const _LiveWorld({required this.world});
  final CurriculumWorld world;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = world.color;
    // This world's Big Thinking game(s) — play → name → bridge → question.
    final thinking = thinkingGamesForWeek(
      ref.watch(thinkingGamesProvider).value ?? const [],
      world.week,
    );
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'This week’s world',
          subtitle: 'The world the room is living in right now',
        ),
        // Hero
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Column(
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
        ),
        const SizedBox(height: 16),
        // Actions
        Wrap(
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
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/action-words/activities?verbs=${world.featuredVerbs.join(',')}',
              ),
              icon: const Icon(Icons.local_activity_outlined),
              label: const Text('Activities'),
            ),
            OutlinedButton.icon(
              onPressed: () => unawaited(printWorldWorksheets(world)),
              icon: const Icon(Icons.print_outlined),
              label: const Text('Worksheets'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/wall'),
              icon: const Icon(Icons.dashboard_customize_outlined),
              label: const Text('The Wall'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/time-capsules'),
              icon: const Icon(Icons.lock_clock_outlined),
              label: const Text('Time capsules'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/action-words/different-worlds'),
              icon: const Icon(Icons.public_outlined),
              label: const Text('Explore all worlds'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Verbs
        _Label(text: 'This week’s verbs', accent: accent),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final id in world.featuredVerbs)
              if (verbById(id) case final v?)
                Chip(
                  label: Text('${v.emoji} ${v.label}'),
                  visualDensity: VisualDensity.compact,
                ),
          ],
        ),
        const SizedBox(height: 20),
        // The world's three rules — every kid hears all three; each kid's
        // verbs decide which one is theirs.
        if (rulesForWorld(world.id).isNotEmpty) ...[
          _Label(text: 'The rules of this world', accent: accent),
          for (final rule in rulesForWorld(world.id))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('§  ', style: TextStyle(color: accent, height: 1.4)),
                  Expanded(
                    child: Text(rule.text, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],
        // Watch -> Do
        if (world.videos.isNotEmpty) ...[
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
          const SizedBox(height: 20),
        ],
        // Big thinking — this world's play→name→bridge→question game(s).
        if (thinking.isNotEmpty) ...[
          _Label(text: 'Big thinking', accent: accent),
          for (final g in thinking)
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
          const SizedBox(height: 20),
        ],
        // Activities
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

/// Two ways to cast a world: mirror this device's screen (cable / AirPlay,
/// no code) or send it to a separate paired screen via the join-code flow.
Future<void> _castOptions(BuildContext context, CurriculumWorld world) {
  return showGlassSheet<void>(
    context: context,
    builder: (sheetCtx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.screen_share_outlined),
            title: const Text('Mirror to this screen'),
            subtitle: const Text(
              'Show it right here — for a projector by cable or AirPlay',
            ),
            onTap: () {
              final router = GoRouter.of(sheetCtx);
              Navigator.of(sheetCtx).pop();
              unawaited(router.push('/present-world/${world.id}'));
            },
          ),
          ListTile(
            leading: const Icon(Icons.cast),
            title: const Text('Send to a paired screen'),
            subtitle: const Text(
              'The screen shows a code; enter it, then drive from here',
            ),
            onTap: () {
              final router = GoRouter.of(sheetCtx);
              Navigator.of(sheetCtx).pop();
              unawaited(router.push('/cast'));
            },
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
