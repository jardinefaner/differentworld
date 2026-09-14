import 'package:differentworld/shared/widgets/app_gap.dart';
import 'package:flutter/material.dart';

/// A deck tile in a "grid of cards" hub — Present, Brain Breaks, Role Cards.
/// One shape, so the decks read as one system.
///
/// **The accent is a category SIGNAL, not a fill.** The tile sits on a soft
/// wash of its accent over the themed surface; the accent itself shows at full
/// strength only in the leading icon. This is the brand's "glow is a scarce
/// resource" law made structural: a grid of fourteen full-bleed colour blocks
/// has fourteen heroes, which is the same as none, and it fought the calm
/// warm-paper language every other screen speaks. At a twentieth of the area
/// the palette still tells you which deck you're looking at, and the screen
/// stops shouting.
///
/// Because the wash is composited over the *theme's* surface, title and tagline
/// read from `onSurface` / `onSurfaceVariant` and follow OS dark/light for
/// free. That also retires the white-on-amber contrast trap this widget was
/// originally built to work around (docs/THEME_ADHERENCE.md) — there is no
/// longer a bright fill for text to sit on.
///
/// Content is **top-aligned and hugs**. The previous shape put a `Spacer()`
/// between the icon and the title inside a fixed-height cell, so a one-line
/// tagline and a three-line tagline pushed their titles to different heights —
/// the ragged, half-empty grid. Everything is flush to the top now, so titles
/// line up across a row whatever the tagline does.
///
/// Provide exactly one leading: an [icon] (tinted to the accent) or an [emoji]
/// (a full-colour glyph, rendered untinted).
class AccentCardTile extends StatelessWidget {
  const AccentCardTile({
    required this.color,
    required this.title,
    this.tagline,
    this.icon,
    this.emoji,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.chips = const <TileChip>[],
    super.key,
  }) : assert(
         (icon == null) != (emoji == null),
         'Provide exactly one of icon or emoji.',
       );

  /// The category accent. Tints the tile's ground and colours the icon; never
  /// used as a solid fill behind text.
  final Color color;
  final String title;
  final String? tagline;

  /// Leading icon — drawn in the accent. Mutually exclusive with [emoji].
  final IconData? icon;

  /// Leading emoji glyph — rendered in its own colours (never tinted).
  /// Mutually exclusive with [icon].
  final String? emoji;

  final VoidCallback? onTap;

  /// Secondary action — used by the decks for "put this on the room's screen".
  /// A long-press keeps the grid free of a per-tile cast button, which at
  /// fourteen tiles would be fourteen competing affordances.
  ///
  /// Bound to RIGHT-CLICK as well as long-press. Press-and-hold with a mouse
  /// technically works, but nobody discovers it — a laptop user reaches for
  /// the context menu. Shipping this as long-press only (2026-09-03) put a
  /// mobile-shaped gesture on a desktop target, which is exactly the drift
  /// docs/PLATFORM_RUBRIC.md exists to catch.
  final VoidCallback? onLongPress;

  /// One clean screen-reader announcement for the whole tile; when set, the
  /// inner fragments are excluded so it reads as a single button.
  final String? semanticLabel;

  /// What this card needs, at a glance — "2 teams", "90s", "camera".
  ///
  /// At most two are drawn. Three chips on a tile is a second tagline in
  /// disguise, and a scroll of fifty tiles each wearing three is the wall the
  /// chips exist to break up. The caller orders them; the tile keeps the
  /// front of the list, so what you would be STOPPED by survives.
  final List<TileChip> chips;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Composited, not translucent: alphaBlend resolves against the real
    // surface so the result is opaque and identical whatever sits behind the
    // grid. 0.14 is the most tint that still leaves onSurface comfortably
    // above AA on the darkest accents in light mode.
    final ground = Color.alphaBlend(
      color.withValues(alpha: 0.14),
      scheme.surfaceContainerHighest,
    );
    // The hairline keeps the tile legible when its accent is close to the
    // surface (the browns and greys) — without it those cells dissolve.
    final edge = Color.alphaBlend(color.withValues(alpha: 0.30), ground);

    final tile = Material(
      color: ground,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: edge, width: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji case final e?)
                Text(e, style: const TextStyle(fontSize: 24))
              else
                Icon(icon, color: color, size: 24),
              const SizedBox(height: 10),
              // Both text blocks are Flexible so the tile degrades instead of
              // overflowing when its cell is a few pixels short of the natural
              // height — which happens on the narrower decks (Role Cards' 150dp
              // cells wrap more titles to two lines) and at large text scales.
              // A grid cell is a fixed extent; the tile must survive being
              // slightly wrong about it rather than throwing a RenderFlex.
              Flexible(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
              if (tagline case final t?) ...[
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    t,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 8),
                // Not Flexible, and not wrapped: a chip row that reflows to a
                // second line changes the tile's height, and these sit in a
                // fixed-extent grid cell. One line, clipped, in a row that can
                // give up its last chip rather than overflow.
                _ChipRow(chips: chips.take(2).toList(), accent: color),
              ],
            ],
          ),
        ),
      ),
    );
    if (semanticLabel case final label?) {
      return Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: tile,
      );
    }
    return tile;
  }
}

/// One glanceable fact on a tile — a label and the icon that carries it at a
/// distance, since at 11sp the word is read second.
@immutable
class TileChip {
  const TileChip(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// The chips, on one line, in the accent's own quiet register.
///
/// They are drawn from the tile's accent rather than a semantic colour: these
/// are properties of the activity, not statuses, and a red "camera" chip would
/// read as a warning about a thing that is merely true.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.chips, required this.accent});

  final List<TileChip> chips;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = Color.alphaBlend(
      accent.withValues(alpha: 0.75),
      theme.colorScheme.onSurfaceVariant,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, chip) in chips.indexed) ...[
          if (i > 0) const AppGap.lg(),
          // Flexible so a long label in a narrow cell gives up its own text
          // rather than the row overflowing. The icon always survives.
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(chip.icon, size: 13, color: ink),
                const AppGap.xs(),
                Flexible(
                  child: Text(
                    chip.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
