import 'package:flutter/material.dart';

/// The small label that sits above a section title, a hero, or a focus block —
/// "Right now", "Question of the day", "Your story so far".
///
/// **This exists because the treatment was retyped by hand in sixty-one
/// files.** There was no widget to import, so every screen re-derived it, and
/// what they re-derived was the Jost-era voice the brand explicitly retired:
/// `labelSmall` + `.toUpperCase()` + `FontWeight.w800` + wide tracking. BRAND.md
/// law 4 says sentence case everywhere, no uppercase shouting, no w800+ weights
/// outside the raw stages — and nothing in the repo checked type, so the drift
/// was invisible while colour adherence was enforced three different ways.
///
/// So the shape is the law, made importable:
///
/// - **Sentence case.** Pass the text as you want it read. This deliberately
///   does NOT call `.toUpperCase()` — if it did, every caller would inherit the
///   thing being fixed.
/// - **w600, never heavier.** Hierarchy comes from size and colour, not weight.
/// - **0.2 tracking**, not 0.6–0.9. Enough to settle a small label, not enough
///   to read as a caps lockup.
/// - **`onSurfaceVariant` by default**, so it recedes below the title it
///   introduces. Pass [color] for a content-driven accent (a world colour, a
///   block's tint) — those belong to content, not chrome.
///
/// An eyebrow is a LABEL, not a sentence: two or three words, no terminal
/// punctuation.
class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow(this.text, {this.color, this.icon, super.key});

  /// Written the way it should be read. Sentence case.
  final String text;

  /// Content-driven accent. Defaults to `onSurfaceVariant`.
  final Color? color;

  /// Optional leading glyph, sized to the text rather than to a tap target —
  /// this is never interactive.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurfaceVariant;
    final label = Text(
      text,
      style: theme.textTheme.labelMedium?.copyWith(
        color: fg,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: fg),
        const SizedBox(width: 6),
        Flexible(child: label),
      ],
    );
  }
}
