import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/journey_day_sheet.dart';
import 'package:differentworld/features/action_words/program_hub_bento_setting.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/bento_module.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/program` — the **season hub**: the in-app counterpart to docs/PROGRAM.md.
/// One screen that holds the whole 10-week program at once — where we are in
/// the 50 days, the two layers of skin (the immersive world we're living in +
/// the week's focus), today's day, the journey ahead, the cast surfaces, and
/// each child's growing arc. The zoom-out view that answers "where is the
/// program right now, and who is each child becoming."
class ProgramHubScreen extends ConsumerWidget {
  const ProgramHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(seasonPositionProvider);
    // `seasonPositionProvider` is null BOTH when the journey is genuinely not
    // started AND while the bundled content packs are still resolving. Without
    // this guard the "Start the journey" empty state flashes on cold launch
    // for an active program. Treat "null + content still loading" as loading.
    final contentLoading =
        position == null &&
        (ref.watch(worldBlocksProvider).isLoading ||
            ref.watch(curriculumWorldsProvider).isLoading);
    // A failed bundle parse must NOT fall through to "Start the journey" — that
    // would misdirect the director to setup when the real cause is a load error.
    final contentError =
        position == null &&
        (ref.watch(worldBlocksProvider).hasError ||
            ref.watch(curriculumWorldsProvider).hasError);
    return EdgeScaffold(
      body: contentLoading
          ? const LoadingSlot()
          : contentError
          ? ErrorState(
              title: 'Couldn’t load the program',
              onRetry: () {
                ref
                  ..invalidate(worldBlocksProvider)
                  ..invalidate(curriculumWorldsProvider);
              },
            )
          : position == null
          ? _NotStarted(isDirector: ref.watch(viewerProvider).isDirector)
          : (ref.watch(programHubBentoProvider).value ?? false)
          ? _ActiveBento(position: position)
          : _Active(position: position),
    );
  }
}

class _NotStarted extends StatelessWidget {
  const _NotStarted({required this.isDirector});
  final bool isDirector;

  @override
  Widget build(BuildContext context) {
    if (!isDirector) {
      return const EmptyState(
        icon: Icons.map_outlined,
        title: 'The journey hasn’t started',
        message:
            'Once your director sets the program’s start date, the whole '
            'season lives here.',
      );
    }
    return EmptyState(
      icon: Icons.rocket_launch_outlined,
      title: 'Start the 10-week journey',
      message:
          'Set the week your program begins. The season — every world, '
          'every day, every child’s arc — appears here.',
      action: FilledButton.icon(
        onPressed: () => unawaited(context.push('/this-week')),
        icon: const Icon(Icons.rocket_launch),
        label: const Text('Set up the journey'),
      ),
    );
  }
}

class _Active extends ConsumerWidget {
  const _Active({required this.position});
  final SeasonPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'The program',
          subtitle: 'Where the season is right now',
        ),
        _SeasonHero(position: position),
        const SizedBox(height: 16),
        _TodayCard(position: position),
        const SizedBox(height: 16),
        _TwoLayers(position: position),
        const SizedBox(height: 20),
        const _JourneyAhead(),
        const SizedBox(height: 20),
        _CastRow(accent: position.block.color),
        const SizedBox(height: 24),
        const _ChildrenArcs(),
      ],
    );
  }
}

/// The immersive world + the unambiguous position (Day N of 50 · Week W of 10)
/// + a 50-day progress bar.
class _SeasonHero extends StatelessWidget {
  const _SeasonHero({required this.position});
  final SeasonPosition position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = position.block;
    final accent = block.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(block.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 4),
          Text(
            block.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Day ${position.day} of 50  ·  Week ${position.week} of 10',
            style: theme.textTheme.labelLarge?.copyWith(color: accent),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: 'Journey progress: day ${position.day} of 50',
            value: '${(position.day / 50 * 100).round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: position.day / 50,
                minHeight: 8,
                backgroundColor: accent.withValues(alpha: 0.18),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's authored day — title + wall question; tap opens the full day sheet.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.position});
  final SeasonPosition position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = position.journeyDay;
    if (day == null) return const SizedBox.shrink();
    final accent = position.block.color;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          unawaited(
            showJourneyDaySheet(
              context,
              day: position.day,
              journeyDay: day,
              block: position.block,
              wallQuestion: position.wallQuestion,
              isToday: true,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (position.wallQuestion != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '“${position.wallQuestion}”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// The two layers of skin, made explicit (the reconciliation in the UI): the
/// immersive WORLD (where you live) + the week's FOCUS (the verbs you work on)
/// — never two competing "World of X" titles. See docs/PROGRAM.md.
class _TwoLayers extends StatelessWidget {
  const _TwoLayers({required this.position});
  final SeasonPosition position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = position.block.color;
    final verbs = position.world == null
        ? const <Verb>[]
        : verbsByIds(position.world!.featuredVerbs);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniLabel(text: 'The world you’re living in', accent: accent),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(position.block.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${position.block.name}  ·  week ${position.block.week}',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        if (verbs.isNotEmpty) ...[
          const SizedBox(height: 16),
          _MiniLabel(text: 'This week’s focus', accent: accent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in verbs)
                Chip(
                  label: Text('${v.emoji} ${v.label}'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The five immersive worlds as a progress strip — past / current / upcoming.
class _JourneyAhead extends ConsumerWidget {
  const _JourneyAhead();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocks = ref.watch(worldBlocksProvider).value ?? const <WorldBlock>[];
    final today = ref.watch(currentProgramDayProvider);
    if (blocks.isEmpty || today == null) return const SizedBox.shrink();
    final current = blockForDay(blocks, today);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniLabel(
          text: 'The journey',
          accent: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final b in blocks)
              _JourneyChip(block: b, isCurrent: b == current),
          ],
        ),
      ],
    );
  }
}

class _JourneyChip extends StatelessWidget {
  const _JourneyChip({required this.block, required this.isCurrent});
  final WorldBlock block;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = block.color;
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? accent.withValues(alpha: 0.22)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: isCurrent ? Border.all(color: accent, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(block.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 2),
          Text(
            // A word, not just color, marks "current" (no color-only signal).
            isCurrent ? 'NOW' : 'wk ${block.week}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isCurrent ? accent : theme.colorScheme.onSurfaceVariant,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: isCurrent ? 0.5 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cast the season — play today, walk the journey, open this week.
class _CastRow extends StatelessWidget {
  const _CastRow({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: accent),
          onPressed: () => unawaited(context.push('/play-today')),
          icon: const Icon(Icons.play_circle_fill),
          label: const Text('Play today'),
        ),
        OutlinedButton.icon(
          onPressed: () => unawaited(context.push('/journey')),
          icon: const Icon(Icons.travel_explore),
          label: const Text('The journey'),
        ),
        OutlinedButton.icon(
          onPressed: () => unawaited(context.push('/this-week')),
          icon: const Icon(Icons.rocket_launch_outlined),
          label: const Text('This week'),
        ),
        OutlinedButton.icon(
          onPressed: () => unawaited(
            showCastToRoom(
              context,
              mirrorRoute: '/journey',
              mirrorSubtitle:
                  'Open the journey here, then mirror to the TV — or set it '
                  'auto-advancing for a hands-free season opener.',
            ),
          ),
          icon: const Icon(Icons.cast),
          label: const Text('Cast to the room'),
        ),
      ],
    );
  }
}

/// Each child's growing arc — collected worlds + emerging title, tap to cast
/// their story.
class _ChildrenArcs extends ConsumerWidget {
  const _ChildrenArcs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    if (subjects.isEmpty) return const SizedBox.shrink();
    // ONE space-wide collections stream, looked up per child — not an
    // actionWordsCollectionProvider family watch per row (N Drift watches).
    final collections =
        ref.watch(actionWordsCollectionsBySubjectProvider).value ??
        const <String, ActionWordsCollection>{};
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniLabel(
          text: 'The children · tap for their day',
          accent: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        for (final s in subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChildArcRow(subject: s, collection: collections[s.id]),
          ),
      ],
    );
  }
}

class _ChildArcRow extends StatelessWidget {
  const _ChildArcRow({required this.subject, required this.collection});
  final Subject subject;

  /// Resolved once from the space-wide map — not watched per row.
  final ActionWordsCollection? collection;

  @override
  Widget build(BuildContext context) {
    final fullName = '${subject.firstName} ${subject.lastName}'.trim();
    final worlds = collection?.collectedWorlds ?? 0;
    final title = collection?.emergingTitle;
    final subtitle =
        title ??
        (worlds == 0
            ? 'Just starting'
            : '$worlds ${worlds == 1 ? 'world' : 'worlds'} collected');
    return FeatureCard(
      leading: PersonAvatar(name: fullName, photoUrl: subject.photoUrl),
      title: fullName,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => unawaited(context.push('/subjects/${subject.id}/day')),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel({required this.text, required this.accent});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}

// ─── Bento variant (opt-in via programHubBentoProvider) ──────────────────────

/// The season hub re-poured onto a [BentoGrid] — the SAME providers as
/// [_Active], modular tiles that re-pack across phone / tablet / desktop. The
/// children's arcs follow as a responsive card grid (variable count → a Wrap,
/// not a fixed-row tile). Reversible: Settings → Preferences flips back to
/// [_Active]. No data rebuilt — pure re-layout.
class _ActiveBento extends ConsumerWidget {
  const _ActiveBento({required this.position});
  final SeasonPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final verbs = position.world == null
        ? const <Verb>[]
        : verbsByIds(position.world!.featuredVerbs);
    final tiles = <BentoTile>[
      BentoTile(
        id: 'world',
        span: const BentoSpan.hero(),
        child: _WorldTile(position: position),
      ),
      BentoTile(
        id: 'today',
        span: const BentoSpan(rows: 2),
        child: _TodayTile(position: position),
      ),
      BentoTile(
        id: 'cast',
        span: const BentoSpan(phone: 1),
        child: _CastTile(accent: position.block.color),
      ),
      BentoTile(
        id: 'focus',
        span: const BentoSpan(phone: 1),
        child: _FocusTile(verbs: verbs, accent: position.block.color),
      ),
      const BentoTile(
        id: 'journey',
        span: BentoSpan(tablet: 4),
        child: _JourneyTile(),
      ),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ContentHeader(
              title: 'The program',
              subtitle: 'Where the season is right now',
            ),
            BentoGrid(tiles: tiles),
            const SizedBox(height: 20),
            const _ChildrenArcsGrid(),
          ],
        ),
      ),
    );
  }
}

/// Hero tile — the immersive world filled with its accent; day N of 50 + a
/// progress bar. Tap opens this week.
class _WorldTile extends StatelessWidget {
  const _WorldTile({required this.position});
  final SeasonPosition position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final block = position.block;
    final accent = block.color;
    final fg = AppColors.onAccent(accent);
    return BentoModule(
      background: accent,
      foreground: fg,
      onTap: () => unawaited(context.push('/this-week')),
      semanticLabel: '${block.name}, day ${position.day} of 50',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(block.emoji, style: const TextStyle(fontSize: 34)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  block.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Day ${position.day} of 50  ·  Week ${position.week} of 10',
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: position.day / 50,
              minHeight: 8,
              backgroundColor: fg.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation(fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today tile — the authored day + wall question; tap opens the day sheet (or
/// this week before the journey is authored).
class _TodayTile extends StatelessWidget {
  const _TodayTile({required this.position});
  final SeasonPosition position;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final day = position.journeyDay;
    return BentoModule(
      background: scheme.surfaceContainerHigh,
      foreground: scheme.onSurface,
      onTap: () {
        if (day == null) {
          unawaited(context.push('/this-week'));
          return;
        }
        unawaited(
          showJourneyDaySheet(
            context,
            day: position.day,
            journeyDay: day,
            block: position.block,
            wallQuestion: position.wallQuestion,
            isToday: true,
          ),
        );
      },
      semanticLabel: 'Today: ${day?.title ?? 'open this week'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoModuleIcon(
                icon: Icons.wb_sunny_outlined,
                tint: scheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 10),
              Text(
                'Today',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            day?.title ?? 'Set up this week',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (position.wallQuestion != null) ...[
            const SizedBox(height: 6),
            Text(
              '“${position.wallQuestion}”',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Cast tile — play today's reveal.
class _CastTile extends StatelessWidget {
  const _CastTile({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = AppColors.onAccent(accent);
    return BentoModule(
      background: accent,
      foreground: fg,
      onTap: () => unawaited(context.push('/play-today')),
      semanticLabel: 'Play today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.play_circle_fill, size: 26, color: fg),
          const SizedBox(height: 12),
          Text(
            'Play today',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Cast the day',
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

/// Focus tile — this week's verbs. Tap opens this week.
class _FocusTile extends StatelessWidget {
  const _FocusTile({required this.verbs, required this.accent});
  final List<Verb> verbs;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BentoModule(
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
      onTap: () => unawaited(context.push('/this-week')),
      semanticLabel: 'This week’s focus',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS WEEK’S FOCUS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          if (verbs.isEmpty)
            Text(
              'Pick this week’s verbs',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final v in verbs.take(4))
                  Text(
                    '${v.emoji} ${v.label}',
                    style: theme.textTheme.bodyMedium,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Journey tile (wide) — the five immersive worlds as a progress strip.
class _JourneyTile extends ConsumerWidget {
  const _JourneyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blocks = ref.watch(worldBlocksProvider).value ?? const <WorldBlock>[];
    final today = ref.watch(currentProgramDayProvider);
    final current = (blocks.isEmpty || today == null)
        ? null
        : blockForDay(blocks, today);
    return BentoModule(
      background: scheme.surfaceContainerHigh,
      foreground: scheme.onSurface,
      onTap: () => unawaited(context.push('/journey')),
      semanticLabel: 'The journey',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THE JOURNEY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in blocks)
                _JourneyChip(block: b, isCurrent: b == current),
            ],
          ),
        ],
      ),
    );
  }
}

/// The children's arcs as a responsive card grid (1 col phone / 2 tablet / 3
/// desktop) — a Wrap, since the count is variable and a fixed-row tile would
/// clip. Same `_ChildArcRow` cards + the same de-N+1'd collections map.
class _ChildrenArcsGrid extends ConsumerWidget {
  const _ChildrenArcsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    if (subjects.isEmpty) return const SizedBox.shrink();
    final collections =
        ref.watch(actionWordsCollectionsBySubjectProvider).value ??
        const <String, ActionWordsCollection>{};
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniLabel(
          text: 'The children · tap for their day',
          accent: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth < 600
                ? 1
                : c.maxWidth < 1100
                ? 2
                : 3;
            final w = cols == 1
                ? c.maxWidth
                : (c.maxWidth - (cols - 1) * 10) / cols;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in subjects)
                  SizedBox(
                    width: w,
                    child: _ChildArcRow(
                      subject: s,
                      collection: collections[s.id],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
