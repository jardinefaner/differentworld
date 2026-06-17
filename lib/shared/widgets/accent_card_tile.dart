import 'package:differentworld/app/design_tokens.dart';
import 'package:flutter/material.dart';

/// A deck tile painted on a bright content accent (an `ActivityPalette`
/// colour, a world colour). One shape, reused by every "grid of coloured
/// cards" hub — Present, Brain Breaks, Role Cards — so the decks read as one
/// system and the contrast fix lives in ONE place.
///
/// The foreground (icon + title + tagline) is chosen by
/// [AppColors.onAccent] from the fill's luminance: black on the light
/// accents (amber/yellow/blue/teal), white on the dark ones. A hardcoded
/// `Colors.white` here fails WCAG AA on the light fills (white-on-amber
/// ≈1.9:1) — the bug this widget exists to prevent (docs/THEME_ADHERENCE.md).
///
/// Provide exactly one leading: an [icon] (tinted to the foreground) or an
/// [emoji] (a full-colour glyph, rendered untinted). The cell is meant to be
/// laid out by a text-scale-aware grid (a `mainAxisExtent` that grows with
/// `textScaler`); the title/tagline still ellipsize as a last resort.
class AccentCardTile extends StatelessWidget {
  const AccentCardTile({
    required this.color,
    required this.title,
    this.tagline,
    this.icon,
    this.emoji,
    this.onTap,
    this.semanticLabel,
    super.key,
  }) : assert(
          (icon == null) != (emoji == null),
          'Provide exactly one of icon or emoji.',
        );

  /// The accent fill. The foreground derives from this via [AppColors.onAccent].
  final Color color;
  final String title;
  final String? tagline;

  /// Leading icon — tinted to the readable foreground. Mutually exclusive
  /// with [emoji].
  final IconData? icon;

  /// Leading emoji glyph — rendered in its own colours (never tinted).
  /// Mutually exclusive with [icon].
  final String? emoji;

  final VoidCallback? onTap;

  /// One clean screen-reader announcement for the whole tile; when set, the
  /// inner fragments are excluded so it reads as a single button.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fg = AppColors.onAccent(color);
    final tile = Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (emoji case final e?)
                Text(e, style: const TextStyle(fontSize: 36))
              else
                Icon(icon, color: fg, size: 36),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (tagline case final t?) ...[
                const SizedBox(height: 2),
                Text(
                  t,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (semanticLabel case final label?) {
      return Semantics(button: true, label: label, excludeSemantics: true, child: tile);
    }
    return tile;
  }
}
