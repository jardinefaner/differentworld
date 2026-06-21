import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/accent_card_tile.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/present` — the classroom remote hub (docs/VISION.md #18). One place to
/// put something on the room's screen and control it from the phone: the
/// non-game presentables (Now & Next, Poll, Spotlight, Signals) + a bridge to
/// the brain-break games. Each card opens the single-device runner, which
/// carries a cast action to go two-device live.
///
/// Two layouts over the SAME deck list: the responsive accent-card grid
/// (default) and a BENTO grid (opt-in via the global "Bento everywhere"
/// switch) that weights the remote action over the equal-weight presentables.
class PresentHubScreen extends ConsumerWidget {
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
      title: 'Live Board',
      tagline: 'Type a word, spell for a kid — live on every screen',
      icon: Icons.draw_outlined,
      color: ActivityPalette.cyan,
      route: '/live-board',
    ),
    _PresentCard(
      title: 'Now & Next',
      tagline: "What's on now — and next",
      icon: Icons.calendar_view_day_outlined,
      color: ActivityPalette.teal,
      route: '/present/now-next',
    ),
    _PresentCard(
      title: 'Name It',
      tagline: 'Picture up — say the word',
      icon: Icons.style_outlined,
      color: ActivityPalette.purple,
      route: '/present/name-it',
    ),
    _PresentCard(
      title: 'Odd One Out',
      tagline: 'Three match, one doesn’t — spot it',
      icon: Icons.category_outlined,
      color: ActivityPalette.red,
      route: '/present/odd-one-out',
    ),
    _PresentCard(
      title: "What's Missing",
      tagline: 'Study the set — what vanished?',
      icon: Icons.visibility_off_outlined,
      color: ActivityPalette.pink,
      route: '/present/whats-missing',
    ),
    _PresentCard(
      title: 'Memory',
      tagline: 'Match the pairs — tap two to flip',
      icon: Icons.grid_view_rounded,
      color: ActivityPalette.indigo,
      route: '/present/memory-match',
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
  Widget build(BuildContext context, WidgetRef ref) {
    // `perScreen: null` — only the global "Bento everywhere" switch gates this
    // screen (no per-screen toggle of its own).
    final bento = bentoEnabled(ref, perScreen: null);

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
              child: bento ? _bentoGrid(context) : _accentGrid(context),
            ),
          ],
        ),
      ),
    );
  }

  /// The default layout — the responsive accent-card grid.
  Widget _accentGrid(BuildContext context) {
    return GridView(
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
    );
  }

  /// The bento variant — SAME deck list, re-laid as weighted tiles. The remote
  /// ("Cast to a screen") leads as a full-width banner; the rest are uniform
  /// 2×1 presentables that pack into clean runs beneath it — a hub of
  /// equal-weight destinations reads as a uniform grid (docs/GRID.md), and a
  /// full-width lead avoids the gap a 2-row hero would leave at desktop where
  /// `Wrap` won't back-fill. Each tile bounds the [AccentCardTile] in a
  /// text-scale-aware height because the tile body uses a `Spacer` (an
  /// unbounded bento cell would otherwise throw; see docs/GRID.md).
  Widget _bentoGrid(BuildContext context) {
    final tileHeight = 140 + 64 * _textScale(context);
    return BentoGrid(
      tiles: [
        for (var i = 0; i < _cards.length; i++)
          BentoTile(
            id: 'present-${_cards[i].route}',
            // The remote leads as a full-width banner; every presentable is an
            // equal-weight 2×1 below it.
            span: i == 0 ? const BentoSpan.wide() : const BentoSpan(),
            child: SizedBox(
              height: tileHeight,
              child: AccentCardTile(
                color: _cards[i].color,
                icon: _cards[i].icon,
                title: _cards[i].title,
                tagline: _cards[i].tagline,
                onTap: () => unawaited(context.push(_cards[i].route)),
              ),
            ),
          ),
      ],
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
