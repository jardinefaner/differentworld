import 'package:differentworld/app/design_tokens.dart';
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
  }) =>
      Text(
        text,
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
  static Widget frame(
    BuildContext context, {
    required Widget hero,
    String? eyebrow,
    Widget? body,
  }) =>
      Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eyebrow case final e?) ...[
                    GameStage.eyebrow(context, e),
                    const SizedBox(height: 20),
                  ],
                  hero,
                  ?body,
                ],
              ),
            ),
          ),
        ),
      );

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
      style: TextStyle(color: fg, fontSize: fontSize, fontWeight: FontWeight.w500),
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
                  style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: fontSize),
                ),
              ],
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
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w400,
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
