import 'dart:async';
import 'dart:math';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/calm/calm_setting.dart';
import 'package:differentworld/features/daily/daily_setting.dart';
import 'package:differentworld/features/heroes/heroes_setting.dart';
import 'package:differentworld/features/recap/recap_setting.dart';
import 'package:differentworld/features/routines/routines_setting.dart';
import 'package:differentworld/features/spellbook/spellbook_setting.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/accent_card_tile.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
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
  static final _cards = <_BreakCard>[
    // "Do It" leads — the one card that sends the room OFF the screen to do
    // a real thing, and keeps a record of it (docs/VISION.md 2026-06-18).
    const _BreakCard(
      title: 'Do It',
      tagline: 'A real thing to go do',
      icon: Icons.directions_run_outlined,
      color: ActivityPalette.green,
      route: '/activity/do-it',
    ),
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
      title: 'Fill in the Blank',
      tagline: 'Silly words → read it aloud',
      icon: Icons.edit_note_outlined,
      color: ActivityPalette.amber,
      route: '/activity/fill-blank',
    ),
    const _BreakCard(
      title: 'Letters',
      tagline: 'Write to a friend',
      icon: Icons.mail_outline,
      color: ActivityPalette.pink,
      route: '/activity/letters',
    ),
    const _BreakCard(
      title: 'Penny for a Thought',
      tagline: 'Share a thought, count a penny',
      icon: Icons.toll_outlined,
      color: ActivityPalette.amber,
      route: '/activity/penny',
    ),
    const _BreakCard(
      title: 'Potions',
      tagline: 'Gather, stir, name your potion',
      icon: Icons.science_outlined,
      color: ActivityPalette.green,
      route: '/activity/potions',
    ),
    const _BreakCard(
      title: 'Charades',
      tagline: 'Act it out — phone + screen',
      icon: Icons.theater_comedy_outlined,
      color: ActivityPalette.purple,
      route: '/live/charades',
    ),
  ];

  void _surprise(BuildContext context, List<_BreakCard> cards) {
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
    final tileExtent = 140 + 64 * scale;
    // Heroes is opt-in — slot its card in right after Do It (the two
    // "leaves something behind" genres lead the deck) only when switched on.
    final heroesOn = ref.watch(heroesEnabledProvider).value ?? false;
    final routinesOn = ref.watch(routinesEnabledProvider).value ?? false;
    final dailyOn = ref.watch(dailyEnabledProvider).value ?? false;
    final calmOn = ref.watch(calmEnabledProvider).value ?? false;
    final spellbookOn = ref.watch(spellbookEnabledProvider).value ?? false;
    final recapOn = ref.watch(recapEnabledProvider).value ?? false;
    final cards = <_BreakCard>[..._cards];
    // Opt-in cards slot in right after Do It — the room-facing surfaces lead.
    if (spellbookOn) {
      cards.insert(
        1,
        const _BreakCard(
          title: 'Spellbook',
          tagline: 'Open the day’s magic',
          icon: Icons.auto_stories_outlined,
          color: ActivityPalette.deepPurple,
          route: '/spellbook',
        ),
      );
    }
    if (calmOn) {
      cards.insert(
        1,
        const _BreakCard(
          title: 'What to do instead',
          tagline: 'Calm ideas for big feelings',
          icon: Icons.self_improvement_outlined,
          color: ActivityPalette.teal,
          route: '/calm',
        ),
      );
    }
    if (dailyOn) {
      cards.insert(
        1,
        const _BreakCard(
          title: 'Today',
          tagline: 'Question · quote · mission',
          icon: Icons.wb_sunny_outlined,
          color: ActivityPalette.amber,
          route: '/daily',
        ),
      );
    }
    if (recapOn) {
      cards.insert(
        1,
        const _BreakCard(
          title: 'Today’s recap',
          tagline: 'Send each family the day',
          icon: Icons.send_outlined,
          color: ActivityPalette.cyan,
          route: '/recap',
        ),
      );
    }
    if (routinesOn) {
      cards.insert(
        1,
        const _BreakCard(
          title: 'Our day',
          tagline: 'What do we do now?',
          icon: Icons.schedule_outlined,
          color: ActivityPalette.teal,
          route: '/routines',
        ),
      );
    }
    if (heroesOn) {
      cards.insert(
        1,
        const _BreakCard(
          title: 'Heroes',
          tagline: 'Build a make-believe self',
          icon: Icons.auto_awesome_outlined,
          color: ActivityPalette.indigo,
          route: '/heroes',
        ),
      );
    }
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
                  for (final card in cards)
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
