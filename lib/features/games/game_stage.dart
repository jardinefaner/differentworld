import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/games/arrives.dart';
import 'package:differentworld/shared/widgets/app_gap.dart';
import 'package:flutter/material.dart';

/// On-brand type + structure for game stages (docs/GAMES.md — the "fully calm"
/// pass). Stages compose from these instead of hand-rolling oversized bold
/// text: the big serif HERO (Fraunces, via the theme ramp), the tracked-caps
/// EYEBROW, the score COUNTER, the choice OPTION pill, and a centered,
/// width-clamped FRAME with generous air — white-on-dark for the immersive
/// surface. One calm voice across every stage, so the deck reads as one system.
abstract final class GameStage {
  /// The serif hero — the prompt / question / answer / answer-reveal. Big,
  /// centered, LIGHT weight (the brand voice; not a w900 shout).
  static Widget hero(
    BuildContext context,
    String text, {
    int maxLines = 4,
    Color? color,
  }) => Text(
    text,
    // Keyed by its own words, so [frame] can tell one prompt from the next
    // with nothing passed in. A game with a CUSTOM hero (a big letter, a
    // clock) has no words to key on and passes `turn:` instead.
    key: ValueKey(text),
    textAlign: TextAlign.center,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.displaySmall?.copyWith(
      color: color ?? Colors.white,
      fontWeight: FontWeight.w400,
      height: 1.12,
    ),
  );

  /// The eyebrow — a small tracked-caps label above the hero (the instruction
  /// or category). Muted, so the hero leads.
  static Widget eyebrow(BuildContext context, String text) => Text(
    text.toUpperCase(),
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Colors.white.withValues(alpha: 0.5),
      letterSpacing: 1.6,
    ),
  );

  /// A centered, width-clamped column — eyebrow · hero · body — with air. The
  /// shared stage skeleton; pass the per-game body (vote buttons, options, the
  /// reveal note) below the hero.
  /// [turn] identifies WHICH prompt this is — pass it when the hero is custom
  /// (a big letter, a clock) and so has no words of its own to key on.
  /// Defaults to the hero's own key, which [GameStage.hero] supplies.
  static Widget frame(
    BuildContext context, {
    required Widget hero,
    String? eyebrow,
    Widget? body,
    Object? turn,
  }) => Center(
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: _arrives(
            context,
            turn: turn == null ? hero.key : ValueKey(turn),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow case final e?) ...[
                  GameStage.eyebrow(context, e),
                  // The eyebrow block and the hero block — two parts of one
                  // prompt on a big stage, not a form label hugging its field.
                  const AppGap.xxl(),
                ],
                hero,
                ?body,
              ],
            ),
          ),
        ),
      ),
    ),
  );

  /// **How a new prompt arrives** — delegated to [Arrives], which is the one
  /// place that decides, for the stages AND for the bespoke activity screens
  /// that share no stage with them.
  ///
  /// Keyed on the PROMPT, never the body, so a tally tick or a vote landing
  /// updates in place — a stage that re-animated on every tap would be worse
  /// than one that never moved.
  static Widget _arrives(
    BuildContext context, {
    required Key? turn,
    required Widget child,
  }) => Arrives(turn: turn, child: child);

  /// THE choice pill — the ONE atom every game uses for a choice (True/Fib, a
  /// poll option, a math answer, a reveal slot). Flat with a hairline by
  /// default; FILLS with the accent when chosen/correct; DIMS when it's a
  /// rejected alternative. With [trailing] (a count) it becomes a full-width
  /// row. One pill, every game — so the deck shares its interactive atom.
  static Widget option(
    BuildContext context,
    String label, {
    required Color accent,
    bool selected = false,
    bool dimmed = false,
    String? trailing,
    double fontSize = 18,
  }) {
    final fg = selected
        ? AppColors.onAccent(accent)
        : (dimmed ? Colors.white24 : Colors.white);
    final labelText = Text(
      label,
      style: TextStyle(
        color: fg,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
      ),
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        color: selected
            ? accent
            : Colors.white.withValues(alpha: dimmed ? 0.04 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: selected
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: trailing == null
          ? labelText
          : Row(
              children: [
                Expanded(child: labelText),
                Text(
                  trailing,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.75),
                    fontSize: fontSize,
                  ),
                ),
              ],
            ),
    );
  }

  /// The shared end-of-round RECAP — emoji · light headline · muted caption,
  /// centered. The wrap beat the reveal games (Riddles, Fact or Fib) share.
  static Widget recap(
    BuildContext context, {
    required String emoji,
    required String title,
    required String caption,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(caption, style: const TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    );
  }

  /// THE score atom — a big accent number + a muted caption ("FOUND", "3 / 8").
  /// The shared counter for every game that keeps a tally.
  static Widget counter(
    BuildContext context, {
    required String value,
    required String caption,
    required Color accent,
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // A number that jumps from 3 to 4 between frames is the same "what
      // moved?" problem one size down — the count IS the feedback for a tally
      // tap, and it was silent.
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: Tween<double>(begin: 0.72, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          ),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Text(
          value,
          key: ValueKey(value),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
      Text(
        caption.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white38,
          letterSpacing: 1.4,
        ),
      ),
    ],
  );
}
