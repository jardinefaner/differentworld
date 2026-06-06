import 'dart:async';
import 'dart:math';

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

  static const _cards = <_BreakCard>[
    _BreakCard(
      title: 'Quick Picks',
      tagline: 'This or that?',
      icon: Icons.swap_horiz,
      color: Color(0xFFEC407A),
      route: '/activity/this-or-that',
    ),
    _BreakCard(
      title: 'Act It Out',
      tagline: 'Say it as if…',
      icon: Icons.theater_comedy,
      color: Color(0xFFAB47BC),
      route: '/activity/as-if',
    ),
    _BreakCard(
      title: 'Beat the Letter',
      tagline: 'Words that start with…',
      icon: Icons.abc,
      color: Color(0xFF26A69A),
      route: '/activity/starts-with',
    ),
    _BreakCard(
      title: 'Math Game',
      tagline: 'One question at a time',
      icon: Icons.quiz_outlined,
      color: Color(0xFF42A5F5),
      route: '/activity/math-game',
    ),
    _BreakCard(
      title: 'Many Paths',
      tagline: 'How many ways to a number?',
      icon: Icons.calculate,
      color: Color(0xFF5C6BC0),
      route: '/activity/math',
    ),
    _BreakCard(
      title: 'Photo Studio',
      tagline: 'Capture the moment',
      icon: Icons.photo_camera,
      color: Color(0xFFFFA726),
      route: '/activity/photo',
    ),
    _BreakCard(
      title: 'Role Cards',
      tagline: 'Be an animal — or an astronaut',
      icon: Icons.pets,
      color: Color(0xFF66BB6A),
      route: '/activity/roles',
    ),
    _BreakCard(
      title: 'Make a Pattern',
      tagline: 'Snap a tile, watch it repeat',
      icon: Icons.grid_on,
      color: Color(0xFF7E57C2),
      route: '/activity/pattern',
    ),
    _BreakCard(
      title: 'Group Talk',
      tagline: 'Discuss — by topic & age',
      icon: Icons.forum_outlined,
      color: Color(0xFF26C6DA),
      route: '/activity/discussions',
    ),
    _BreakCard(
      title: 'Riddle Me This',
      tagline: 'Guess the answer',
      icon: Icons.lightbulb_outline,
      color: Color(0xFFFFCA28),
      route: '/activity/riddles',
    ),
    _BreakCard(
      title: 'Reveal the Picture',
      tagline: 'Call a square, guess the picture',
      icon: Icons.grid_on,
      color: Color(0xFF26C6DA),
      route: '/activity/grid-reveal',
    ),
    _BreakCard(
      title: 'Mindful Minute',
      tagline: 'Breathe together',
      icon: Icons.spa_outlined,
      color: Color(0xFF26A69A),
      route: '/activity/breathe',
    ),
    _BreakCard(
      title: 'Fact or Fib',
      tagline: 'True, or made up?',
      icon: Icons.fact_check_outlined,
      color: Color(0xFF7E57C2),
      route: '/activity/fact-or-fib',
    ),
    _BreakCard(
      title: 'Story Starters',
      tagline: 'Build a story together',
      icon: Icons.auto_stories_outlined,
      color: Color(0xFF5C6BC0),
      route: '/activity/story',
    ),
    _BreakCard(
      title: 'Rhyme Time',
      tagline: 'How many rhymes?',
      icon: Icons.music_note_outlined,
      color: Color(0xFFEC407A),
      route: '/activity/rhyme-time',
    ),
    _BreakCard(
      title: 'Charades',
      tagline: 'Act it out — phone + screen',
      icon: Icons.theater_comedy_outlined,
      color: Color(0xFFAB47BC),
      route: '/live/charades',
    ),
  ];

  void _surprise(BuildContext context) {
    final pick = _cards[Random().nextInt(_cards.length)];
    unawaited(context.push(pick.route));
  }

  @override
  Widget build(BuildContext context) {
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
              child: GridView.extent(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
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
              Icon(card.icon, color: Colors.white, size: 36),
              const Spacer(),
              Text(
                card.title,
                style: const TextStyle(
                  color: Colors.white,
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
                  color: Colors.white.withValues(alpha: 0.85),
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
