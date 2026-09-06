import 'dart:async';
import 'dart:math';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/activity_deck.dart';
import 'package:differentworld/features/calm/calm_setting.dart';
import 'package:differentworld/features/daily/daily_setting.dart';
import 'package:differentworld/features/heroes/heroes_setting.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/features/recap/recap_setting.dart';
import 'package:differentworld/features/routines/routines_setting.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/spellbook/spellbook_setting.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/accent_card_tile.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/section_eyebrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/breaks` — the Brain Breaks deck. The home for the activity e-cards:
/// short, card-shaped, low-stakes resets between the real work. The
/// teacher (or a kid) flips here, picks a card, the room does it. Each card
/// launches its activity (which is kid-mode locked from there).
///
/// Deliberately light: a deck of cards + a shuffle. The activities are
/// brain breaks, not lessons — no heavy archiving here.
class BrainBreaksScreen extends ConsumerWidget {
  const BrainBreaksScreen({super.key});

  // `final` (not const): the deck composition is platform-dependent —
  // camera-backed cards only exist where there's a usable camera.
  // Memoized on first access for the whole isolate: in tests, set the
  // platform (e.g. `TargetPlatformVariant`) BEFORE pumping this screen
  // — see brain_breaks_platform_test.dart.
  static final _cards = <DeckCard>[
    // "Do It" leads — the one card that sends the room OFF the screen to do
    // a real thing, and keeps a record of it (docs/VISION.md 2026-06-18).
    const DeckCard(
      title: 'Do It',
      tagline: 'A real thing to go do',
      icon: Icons.directions_run_outlined,
      color: ActivityPalette.green,
      lane: DeckLane.reset,
      route: '/activity/do-it',
    ),
    const DeckCard(
      title: 'This or That',
      tagline: 'This or that?',
      icon: Icons.swap_horiz,
      color: ActivityPalette.pink,
      lane: DeckLane.reset,
      route: '/activity/this-or-that',
    ),
    const DeckCard(
      title: 'Say It As If',
      tagline: 'Say it as if…',
      icon: Icons.theater_comedy,
      color: ActivityPalette.purple,
      lane: DeckLane.reset,
      route: '/activity/as-if',
    ),
    const DeckCard(
      title: 'Beat the Letter',
      tagline: 'Words that start with…',
      icon: Icons.abc,
      color: ActivityPalette.teal,
      lane: DeckLane.reset,
      route: '/activity/starts-with',
    ),
    const DeckCard(
      title: 'Math Game',
      tagline: 'One question at a time',
      icon: Icons.quiz_outlined,
      color: ActivityPalette.blue,
      lane: DeckLane.reset,
      route: '/activity/math-game',
    ),
    const DeckCard(
      title: 'Many Paths',
      tagline: 'How many ways to a number?',
      icon: Icons.calculate,
      color: ActivityPalette.indigo,
      lane: DeckLane.reset,
      route: '/activity/math',
    ),
    // Camera-dependent: hidden where there's no in-app camera
    // (docs/PLATFORM_RUBRIC.md P1 — no dead "take a photo" buttons).
    if (isMobileCapturePlatform)
      const DeckCard(
        title: 'Photo Studio',
        tagline: 'Capture the moment',
        icon: Icons.photo_camera,
        color: ActivityPalette.amber,
        lane: DeckLane.reset,
        route: '/activity/photo',
      ),
    const DeckCard(
      title: 'Role Cards',
      tagline: 'Be an animal — or an astronaut',
      icon: Icons.pets,
      color: ActivityPalette.green,
      lane: DeckLane.reset,
      route: '/activity/roles',
    ),
    const DeckCard(
      title: 'Make a Pattern',
      tagline: 'Snap a tile, watch it repeat',
      icon: Icons.grid_on,
      color: ActivityPalette.deepPurple,
      lane: DeckLane.reset,
      route: '/activity/pattern',
    ),
    const DeckCard(
      title: 'Group Talk',
      tagline: 'Discuss — by topic & age',
      icon: Icons.forum_outlined,
      color: ActivityPalette.cyan,
      lane: DeckLane.reset,
      route: '/activity/discussions',
    ),
    // The classics. Nothing to teach — four generations already know the
    // rules, which is the same reason the stages stopped narrating themselves.
    const DeckCard(
      title: 'Bingo',
      tagline: 'Cross them off as they’re called',
      icon: Icons.grid_view_rounded,
      color: ActivityPalette.amber,
      lane: DeckLane.screen,
      route: '/activity/bingo',
    ),
    const DeckCard(
      title: 'Battleship',
      tagline: 'Call a square — hit or miss',
      icon: Icons.sailing_outlined,
      color: ActivityPalette.blue,
      lane: DeckLane.screen,
      route: '/activity/battleship',
    ),
    const DeckCard(
      title: 'Guess Who',
      tagline: 'Ask, rule them out, one left',
      icon: Icons.face_outlined,
      color: ActivityPalette.purple,
      lane: DeckLane.screen,
      route: '/activity/guess-who',
    ),
    const DeckCard(
      title: 'Connect Four',
      tagline: 'Four in a line wins',
      icon: Icons.circle_outlined,
      color: ActivityPalette.red,
      lane: DeckLane.screen,
      route: '/activity/connect-four',
    ),
    const DeckCard(
      title: 'Riddle Me This',
      tagline: 'Guess the answer',
      icon: Icons.lightbulb_outline,
      color: ActivityPalette.yellow,
      lane: DeckLane.reset,
      route: '/activity/riddles',
    ),
    const DeckCard(
      title: 'Reveal the Picture',
      tagline: 'Call a square, guess the picture',
      icon: Icons.grid_on,
      color: ActivityPalette.cyan,
      lane: DeckLane.reset,
      route: '/activity/grid-reveal',
    ),
    const DeckCard(
      title: 'Mindful Minute',
      tagline: 'Breathe together',
      icon: Icons.spa_outlined,
      color: ActivityPalette.teal,
      lane: DeckLane.reset,
      route: '/activity/breathe',
    ),
    const DeckCard(
      title: 'Fact or Fib',
      tagline: 'True, or made up?',
      icon: Icons.fact_check_outlined,
      color: ActivityPalette.deepPurple,
      lane: DeckLane.reset,
      route: '/activity/fact-or-fib',
    ),
    const DeckCard(
      title: 'Story Starters',
      tagline: 'Build a story together',
      icon: Icons.auto_stories_outlined,
      color: ActivityPalette.indigo,
      lane: DeckLane.reset,
      route: '/activity/story',
    ),
    const DeckCard(
      title: 'Rhyme Time',
      tagline: 'How many rhymes?',
      icon: Icons.music_note_outlined,
      color: ActivityPalette.pink,
      lane: DeckLane.reset,
      route: '/activity/rhyme-time',
    ),
    const DeckCard(
      title: 'Fill in the Blank',
      tagline: 'Silly words → read it aloud',
      icon: Icons.edit_note_outlined,
      color: ActivityPalette.amber,
      lane: DeckLane.reset,
      route: '/activity/fill-blank',
    ),
    const DeckCard(
      title: 'Letters',
      tagline: 'Write to a friend',
      icon: Icons.mail_outline,
      color: ActivityPalette.pink,
      lane: DeckLane.reset,
      route: '/activity/letters',
    ),
    const DeckCard(
      title: 'Penny for a Thought',
      tagline: 'Share a thought, count a penny',
      icon: Icons.toll_outlined,
      color: ActivityPalette.amber,
      lane: DeckLane.reset,
      route: '/activity/penny',
    ),
    const DeckCard(
      title: 'Potions',
      tagline: 'Gather, stir, name your potion',
      icon: Icons.science_outlined,
      color: ActivityPalette.green,
      lane: DeckLane.reset,
      route: '/activity/potions',
    ),
    const DeckCard(
      title: 'Charades',
      tagline: 'Act it out — phone + screen',
      icon: Icons.theater_comedy_outlined,
      color: ActivityPalette.purple,
      lane: DeckLane.reset,
      route: '/live/charades',
    ),
  ];

  void _surprise(BuildContext context, List<DeckCard> cards) {
    final pick = cards[Random().nextInt(cards.length)];
    unawaited(context.push(pick.route));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cells must GROW with the user's text scale — a fixed childAspectRatio
    // is the fixed-height-around-text trap (a11y-basics; caught by the
    // overflow gauntlet): at the 1.5x floor / 2.0x ceiling the wrapped
    // title + tagline need more vertical room than a 0.9-ratio cell has,
    // and the tile's antialias clip was silently cutting them off.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // Sized to the tile's real content (top-aligned, no Spacer): fixed
    // chrome ~66dp (padding + 24dp icon + gap) plus a text block that grows
    // with the user's scale. The old 140+64 was tuned for a Spacer-stretched
    // cell and left ~40% of every tile empty.
    final tileExtent = 64 + 64 * scale;
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the SAME deck of cards re-lays as
    // uniform bento tiles (2-up on a phone); off keeps the existing
    // fixed-extent GridView.
    final bento = bentoEnabled(ref, perScreen: null);
    // Heroes is opt-in — slot its card in right after Do It (the two
    // "leaves something behind" genres lead the deck) only when switched on.
    final heroesOn = ref.watch(heroesEnabledProvider).value ?? false;
    final routinesOn = ref.watch(routinesEnabledProvider).value ?? false;
    final dailyOn = ref.watch(dailyEnabledProvider).value ?? false;
    final calmOn = ref.watch(calmEnabledProvider).value ?? false;
    final spellbookOn = ref.watch(spellbookEnabledProvider).value ?? false;
    final recapOn = ref.watch(recapEnabledProvider).value ?? false;
    final cards = <DeckCard>[..._cards];
    // Opt-in cards slot in right after Do It — the room-facing surfaces lead.
    if (spellbookOn) {
      cards.insert(
        1,
        const DeckCard(
          title: 'Spellbook',
          tagline: 'Open the day’s magic',
          icon: Icons.auto_stories_outlined,
          color: ActivityPalette.deepPurple,
          lane: DeckLane.rhythm,
          route: '/spellbook',
        ),
      );
    }
    if (calmOn) {
      cards.insert(
        1,
        const DeckCard(
          title: 'What to do instead',
          tagline: 'Calm ideas for big feelings',
          icon: Icons.self_improvement_outlined,
          color: ActivityPalette.teal,
          lane: DeckLane.rhythm,
          route: '/calm',
        ),
      );
    }
    if (dailyOn) {
      cards.insert(
        1,
        const DeckCard(
          title: 'Today',
          tagline: 'Question · quote · mission',
          icon: Icons.wb_sunny_outlined,
          color: ActivityPalette.amber,
          lane: DeckLane.rhythm,
          route: '/daily',
        ),
      );
    }
    if (recapOn) {
      cards.insert(
        1,
        const DeckCard(
          title: 'Today’s recap',
          tagline: 'Send each family the day',
          icon: Icons.send_outlined,
          color: ActivityPalette.cyan,
          lane: DeckLane.rhythm,
          route: '/recap',
        ),
      );
    }
    if (routinesOn) {
      cards.insert(
        1,
        const DeckCard(
          title: 'Our day',
          tagline: 'What do we do now?',
          icon: Icons.schedule_outlined,
          color: ActivityPalette.teal,
          lane: DeckLane.rhythm,
          route: '/routines',
        ),
      );
    }
    if (heroesOn) {
      cards.insert(
        1,
        const DeckCard(
          title: 'Heroes',
          tagline: 'Build a make-believe self',
          icon: Icons.auto_awesome_outlined,
          color: ActivityPalette.indigo,
          lane: DeckLane.rhythm,
          route: '/heroes',
        ),
      );
    }
    // The Present deck joins the same library. The two hubs were split on a
    // line that does not exist — same card shape, same tile, every item a
    // route — and Present linked here as though this were a subcategory of
    // itself. One library, grouped by what a thing IS.
    cards.addAll(presentDeck);
    final lanes = [
      for (final lane in DeckLane.values)
        (lane: lane, cards: cards.where((c) => c.lane == lane).toList()),
    ].where((g) => g.cards.isNotEmpty).toList();

    return EdgeScaffold(
      showBack: false,
      actions: [
        PrimaryActionButton(
          tooltip: 'Surprise us',
          icon: Icons.casino_outlined,
          onPressed: () => _surprise(context, cards),
        ),
      ],
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ContentHeader(
                title: 'Do something together',
                subtitle: _deckHint,
              ),
            ),
            for (final group in lanes) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: SectionEyebrow(group.lane.label),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: bento
                    ? _bentoGrid(context, ref, group.cards, tileExtent)
                    : _accentGrid(context, ref, group.cards, tileExtent),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The default layout — the responsive accent-card grid (cells grow with the
  /// text scale via [tileExtent]).
  Widget _accentGrid(
    BuildContext context,
    WidgetRef ref,
    List<DeckCard> cards,
    double tileExtent,
  ) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: tileExtent,
      ),
      children: [
        for (final card in cards)
          AccentCardTile(
            color: card.color,
            icon: card.icon,
            title: card.title,
            tagline: card.tagline,
            onTap: () => unawaited(context.push(card.route)),
            onLongPress: () => unawaited(_castCard(context, ref, card)),
          ),
      ],
    );
  }

  /// The bento variant — the SAME deck list, re-laid as uniform tiles. Every
  /// card is `BentoSpan(phone: 1)` so they pack 2-up on a phone (the grid
  /// read), 4-up on tablet, 3-up on desktop — a deck of equal-weight short
  /// cards reads as a uniform grid (docs/GRID.md). Each tile bounds the
  /// [AccentCardTile] in the SAME text-scale-aware [tileExtent] the flat grid
  /// uses: the tile hugs its content now, but an unbounded bento cell would
  /// otherwise throw; see docs/GRID.md).
  Widget _bentoGrid(
    BuildContext context,
    WidgetRef ref,
    List<DeckCard> cards,
    double tileExtent,
  ) {
    return BentoGrid(
      tiles: [
        for (final card in cards)
          BentoTile(
            id: 'break-${card.route}',
            // phone 1-of-2 (2-up), tablet 1-of-4 (4-up), desktop default
            // 2-of-6 (3-up) — equal-weight short cards in a uniform grid.
            span: const BentoSpan(phone: 1, tablet: 1),
            child: SizedBox(
              height: tileExtent,
              child: AccentCardTile(
                color: card.color,
                icon: card.icon,
                title: card.title,
                tagline: card.tagline,
                onTap: () => unawaited(context.push(card.route)),
                onLongPress: () => unawaited(_castCard(context, ref, card)),
              ),
            ),
          ),
      ],
    );
  }
}

/// Put a break on the room's screen.
///
/// Every card is just a route, so the chooser is route-generic and every card
/// gets one with no per-activity work. What the card does NOT decide is which
/// mechanism it gets — [showCastToRoom] resolves that from the route, because
/// only nine of these can reach a paired TV and the other eighteen would
/// otherwise be offered a screen that stays blank.
Future<void> _castCard(BuildContext context, WidgetRef ref, DeckCard card) {
  return showCastToRoom(
    context,
    ref,
    mirrorRoute: card.route,
    what: card.title,
  );
}

/// "Hold" is a phone gesture; on a laptop the same action is a right-click,
/// and telling a desktop user to hold is telling them to do nothing.
String get _deckHint => isMobileCapturePlatform
    ? 'Tap to run · hold to put it on the screen'
    : 'Tap to run · right-click to put it on the screen';
