import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/shared/widgets/accent_card_tile.dart';
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
      color: ActivityPalette.tealDeep,
      route: '/cast',
    ),
    _PresentCard(
      title: 'Now & Next',
      tagline: "What's on now — and next",
      icon: Icons.calendar_view_day_outlined,
      color: ActivityPalette.teal,
      route: '/present/now-next',
    ),
    _PresentCard(
      title: 'Quick Poll',
      tagline: 'Vote together, see the winner',
      icon: Icons.how_to_vote_outlined,
      color: ActivityPalette.indigo,
      route: '/present/poll',
    ),
    _PresentCard(
      title: 'Spotlight',
      tagline: 'Fair turns — spin for a name',
      icon: Icons.star_outline,
      color: ActivityPalette.amber,
      route: '/present/picker',
    ),
    _PresentCard(
      title: 'Signals',
      tagline: 'Eyes up · Clean up · Breathe',
      icon: Icons.campaign_outlined,
      color: ActivityPalette.blue,
      route: '/present/cues',
    ),
    _PresentCard(
      title: 'Brain Break Games',
      tagline: 'Riddles, This or That, Charades…',
      icon: Icons.sports_esports_outlined,
      color: ActivityPalette.purple,
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
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Cell grows with text scale so the title/tagline never clip
                  // (the fixed-childAspectRatio trap; see brain_breaks).
                  mainAxisExtent: 140 + 64 * _textScale(context),
                ),
                children: [
                  for (final card in _cards)
                    AccentCardTile(
                      color: card.color,
                      icon: card.icon,
                      title: card.title,
                      tagline: card.tagline,
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

/// Title-text-relative scale (1.0 = OS default) so cells grow with the
/// user's text-size setting instead of clipping at a fixed aspect ratio.
double _textScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14;
