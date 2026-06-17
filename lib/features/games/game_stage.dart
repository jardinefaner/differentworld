import 'package:flutter/material.dart';

/// On-brand type + structure for game stages (docs/GAMES.md — the "fully calm"
/// pass). Stages compose from these instead of hand-rolling
/// `TextStyle(fontSize: 240, w900)`: the big serif HERO (Fraunces, via the
/// theme ramp), the tracked-caps EYEBROW, and a centered, width-clamped FRAME
/// with generous air — white-on-dark for the immersive surface. One calm voice
/// across every stage, so the deck reads as one system.
abstract final class GameStage {
  /// The serif hero — the prompt / question / answer / answer-reveal. Big,
  /// centered, LIGHT weight (the brand voice; not a w900 shout).
  static Widget hero(BuildContext context, String text, {int maxLines = 4}) =>
      Text(
        text,
        textAlign: TextAlign.center,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Colors.white,
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
}
