import 'dart:async';

import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// `/present` — the classroom remote hub (docs/VISION.md #18). One place to
/// put something on the room's screen and control it from the phone: the
/// non-game presentables (Now & Next, Poll, Spotlight, Signals) + a bridge to
/// the brain-break games. Each card opens the single-device runner, which
/// carries a cast action to go two-device live.
class PresentHubScreen extends StatelessWidget {
  const PresentHubScreen({super.key});

  static const _cards = <_PresentCard>[
    // The app remote (docs/LIVE_SESSIONS.md "the cast model") — make a screen a
    // clean display and pick / switch / drive it all from this phone.
    _PresentCard(
      title: 'Cast to a screen',
      tagline: 'Phone is the remote — pick, switch, control',
      icon: Icons.cast,
      color: Color(0xFF00897B),
      route: '/cast',
    ),
    _PresentCard(
      title: 'Now & Next',
      tagline: "What's on now — and next",
      icon: Icons.calendar_view_day_outlined,
      color: Color(0xFF26A69A),
      route: '/present/now-next',
    ),
    _PresentCard(
      title: 'Quick Poll',
      tagline: 'Vote together, see the winner',
      icon: Icons.how_to_vote_outlined,
      color: Color(0xFF5C6BC0),
      route: '/present/poll',
    ),
    _PresentCard(
      title: 'Spotlight',
      tagline: 'Fair turns — spin for a name',
      icon: Icons.star_outline,
      color: Color(0xFFFFA726),
      route: '/present/picker',
    ),
    _PresentCard(
      title: 'Signals',
      tagline: 'Eyes up · Clean up · Breathe',
      icon: Icons.campaign_outlined,
      color: Color(0xFF42A5F5),
      route: '/present/cues',
    ),
    _PresentCard(
      title: 'Brain Break Games',
      tagline: 'Riddles, This or That, Charades…',
      icon: Icons.sports_esports_outlined,
      color: Color(0xFFAB47BC),
      route: '/breaks',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      showBack: false,
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ContentHeader(
                title: 'Present',
                subtitle: 'Put it on the big screen — control from your phone',
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
                    _PresentCardTile(
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

class _PresentCard {
  const _PresentCard({
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

class _PresentCardTile extends StatelessWidget {
  const _PresentCardTile({required this.card, required this.onTap});

  final _PresentCard card;
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
