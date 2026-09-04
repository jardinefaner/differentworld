import 'package:flutter/material.dart';

/// The card that carries an activity's prompt — "today's prompt", "gather from
/// the garden", "a thought about…".
///
/// **One shape, so the deck reads as one deck.** Every brain break is different
/// content and that is the point; what should NOT differ is the frame around
/// it. Letters, Potions and Penny each hand-rolled this card, and predictably
/// one of them drifted: Penny's lost the left accent edge the other two have,
/// so the same idea arrived looking like a different app. The fix for "three
/// copies, one drifted" is not to re-align the copies.
///
/// The shape is the brand's first visual law made literal — one left edge,
/// flush-left, flat, no card-within-a-card (docs/BRAND.md):
///
///   • a 4dp accent edge on the LEFT only, rounded on the right
///   • a quiet [eyebrow] naming what this is
///   • the prompt itself, large enough to read across a room
///
/// [tone] varies the fill without varying the structure — that is the whole
/// trick. An instruction card and a result card are recognisably siblings.
class ActivityPrompt extends StatelessWidget {
  const ActivityPrompt({
    required this.eyebrow,
    this.prompt,
    this.child,
    this.tone = ActivityPromptTone.primary,
    this.edgeColor,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    super.key,
  });

  /// What this card IS, in a few quiet words: "today's prompt", "and it…".
  /// Sentence case — BRAND.md law 4.
  final String eyebrow;

  /// The prompt itself, when it is one line of text. Sized to be read at
  /// arm's length by a room. Mutually exclusive with [child].
  final String? prompt;

  /// An arbitrary body, when the prompt is not a sentence — Potions lists its
  /// ingredients here. The SHAPE stays identical either way, which is the
  /// point: an activity's content should be free to differ while the frame
  /// around it does not.
  final Widget? child;

  /// Overrides the accent edge for a content-driven colour (a world's tint, a
  /// recipe's palette entry). The structure is unchanged.
  final Color? edgeColor;

  final ActivityPromptTone tone;

  /// Optional glyph beside the prompt (Potions' sparkle on its outcome card).
  final Widget? leading;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (fill, edge, ink) = switch (tone) {
      ActivityPromptTone.primary => (
        scheme.primaryContainer,
        scheme.primary,
        scheme.onPrimaryContainer,
      ),
      // The quiet variant — a recipe, a set of materials, anything the room
      // reads rather than acts on.
      ActivityPromptTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.outlineVariant,
        scheme.onSurface,
      ),
    };

    assert(
      (prompt == null) != (child == null),
      'Give ActivityPrompt exactly one of prompt or child.',
    );
    final body =
        child ??
        Text(
          prompt!,
          style: theme.textTheme.titleLarge?.copyWith(
            color: ink,
            fontWeight: FontWeight.w600,
          ),
        );

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        // Rounded on the right only: the left edge IS the accent, and rounding
        // it would turn the card into a floating box — the thing law 1 exists
        // to prevent.
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        border: Border(left: BorderSide(color: edgeColor ?? edge, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: ink.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 4),
          if (leading == null)
            body
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading!,
                const SizedBox(width: 10),
                Expanded(child: body),
              ],
            ),
        ],
      ),
    );
  }
}

/// How loud the prompt card is. Structure never changes; only the fill does.
enum ActivityPromptTone {
  /// The thing to do or the thing that happened — the card the room looks at.
  primary,

  /// Supporting material the room reads: a recipe, a list of things to gather.
  neutral,
}
