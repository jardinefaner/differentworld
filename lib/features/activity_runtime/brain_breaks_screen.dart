import 'dart:async';
import 'dart:math';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/breaks` — the Brain Breaks deck. The home for the activity e-cards:
/// short, card-shaped, low-stakes resets between the real work. The
/// teacher (or a kid) flips here, picks a card, the room does it. Each card
/// launches its activity (which is kid-mode locked from there).
///
/// Deliberately light: a deck of cards + a shuffle. The activities are
/// brain breaks, not lessons — no heavy archiving here.
class BrainBreaksScreen extends StatelessWidget {
  const BrainBreaksScreen({super.key});

  // `final` (not const): the deck composition is platform-dependent —
  // camera-backed cards only exist where there's a usable camera.
  // Memoized on first access for the whole isolate: in tests, set the
  // platform (e.g. `TargetPlatformVariant`) BEFORE pumping this screen
  // — see brain_breaks_platform_test.dart.
  static final _cards = <_BreakCard>[
    const _BreakCard(
      title: 'Quick Picks',
      tagline: 'This or that?',
      icon: Icons.swap_horiz,
      color: ActivityPalette.pink,
      route: '/activity/this-or-that',
    ),
    const _BreakCard(
      title: 'Act It Out',
      tagline: 'Say it as if…',
      icon: Icons.theater_comedy,
      color: ActivityPalette.purple,
      route: '/activity/as-if',
    ),
    const _BreakCard(
      title: 'Beat the Letter',
      tagline: 'Words that start with…',
      icon: Icons.abc,
      color: ActivityPalette.teal,
      route: '/activity/starts-with',
    ),
    const _BreakCard(
      title: 'Math Game',
      tagline: 'One question at a time',
      icon: Icons.quiz_outlined,
      color: ActivityPalette.blue,
      route: '/activity/math-game',
    ),
    const _BreakCard(
      title: 'Many Paths',
      tagline: 'How many ways to a number?',
      icon: Icons.calculate,
      color: ActivityPalette.indigo,
      route: '/activity/math',
    ),
    // Camera-dependent: hidden where there's no in-app camera
    // (docs/PLATFORM_RUBRIC.md P1 — no dead "take a photo" buttons).
    if (isMobileCapturePlatform)
      const _BreakCard(
        title: 'Photo Studio',
        tagline: 'Capture the moment',
        icon: Icons.photo_camera,
        color: ActivityPalette.amber,
        route: '/activity/photo',
      ),
    const _BreakCard(
      title: 'Role Cards',
      tagline: 'Be an animal — or an astronaut',
      icon: Icons.pets,
      color: ActivityPalette.green,
      route: '/activity/roles',
    ),
    const _BreakCard(
      title: 'Make a Pattern',
      tagline: 'Snap a tile, watch it repeat',
      icon: Icons.grid_on,
      color: ActivityPalette.deepPurple,
      route: '/activity/pattern',
    ),
    const _BreakCard(
      title: 'Group Talk',
      tagline: 'Discuss — by topic & age',
      icon: Icons.forum_outlined,
      color: ActivityPalette.cyan,
      route: '/activity/discussions',
    ),
    const _BreakCard(
      title: 'Riddle Me This',
      tagline: 'Guess the answer',
      icon: Icons.lightbulb_outline,
      color: ActivityPalette.yellow,
      route: '/activity/riddles',
    ),
    const _BreakCard(
      title: 'Reveal the Picture',
      tagline: 'Call a square, guess the picture',
      icon: Icons.grid_on,
      color: ActivityPalette.cyan,
      route: '/activity/grid-reveal',
    ),
    const _BreakCard(
      title: 'Mindful Minute',
      tagline: 'Breathe together',
      icon: Icons.spa_outlined,
      color: ActivityPalette.teal,
      route: '/activity/breathe',
    ),
    const _BreakCard(
      title: 'Fact or Fib',
      tagline: 'True, or made up?',
      icon: Icons.fact_check_outlined,
      color: ActivityPalette.deepPurple,
      route: '/activity/fact-or-fib',
    ),
    const _BreakCard(
      title: 'Story Starters',
      tagline: 'Build a story together',
      icon: Icons.auto_stories_outlined,
      color: ActivityPalette.indigo,
      route: '/activity/story',
    ),
    const _BreakCard(
      title: 'Rhyme Time',
      tagline: 'How many rhymes?',
      icon: Icons.music_note_outlined,
      color: ActivityPalette.pink,
      route: '/activity/rhyme-time',
    ),
    const _BreakCard(
      title: 'Charades',
      tagline: 'Act it out — phone + screen',
      icon: Icons.theater_comedy_outlined,
      color: ActivityPalette.purple,
      route: '/live/charades',
    ),
  ];

  void _surprise(BuildContext context) {
    final pick = _cards[Random().nextInt(_cards.length)];
    unawaited(context.push(pick.route));
  }

  @override
  Widget build(BuildContext context) {
    // Cells must GROW with the user's text scale — a fixed childAspectRatio
    // is the fixed-height-around-text trap (a11y-basics; caught by the
    // overflow gauntlet): at the 1.5x floor / 2.0x ceiling the wrapped
    // title + tagline need more vertical room than a 0.9-ratio cell has,
    // and the tile's antialias clip was silently cutting them off.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final tileExtent = 140 + 64 * scale;
    return EdgeScaffold(
      showBack: false,
      actions: [
        PrimaryActionButton(
          tooltip: 'Surprise us',
          icon: Icons.casino_outlined,
          onPressed: () => _surprise(context),
        ),
      ],
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ContentHeader(
                title: 'Brain Breaks',
                subtitle: 'Quick resets — pick a card',
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: tileExtent,
                ),
                children: [
                  for (final card in _cards)
                    _BreakCardTile(
                      card: card,
                      onTap: () => unawaited(context.push(card.route)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreakCard {
  const _BreakCard({
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String title;
  final String tagline;
  final IconData icon;
  final Color color;
  final String route;
}

class _BreakCardTile extends StatelessWidget {
  const _BreakCardTile({required this.card, required this.onTap});

  final _BreakCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: card.color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(card.icon, color: AppColors.onAccent(card.color), size: 36),
              const Spacer(),
              Text(
                card.title,
                // Final guard for extreme narrow×scale combos; the cell
                // height already grows with text scale (build above).
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onAccent(card.color),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                card.tagline,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.onAccent(card.color).withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
