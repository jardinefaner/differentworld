import 'package:flutter/material.dart';

/// The Calm "one left edge" card — a flat `surfaceContainerHighest` panel
/// with a 4dp accent left edge, square left corners and rounded right ones,
/// topped by an optional lowercase eyebrow label (with an optional accent
/// icon). One shape shared by the Daily prompt/mission cards and the recap
/// composer's room/photos cards so the brand edge never drifts per screen.
class AccentEdgeCard extends StatelessWidget {
  const AccentEdgeCard({
    required this.accent,
    required this.children,
    this.eyebrow,
    this.eyebrowIcon,
    this.eyebrowGap = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 14),
    this.margin,
    super.key,
  });

  /// The left-edge (and eyebrow-icon) accent colour — a content colour
  /// (`ActivityPalette`), not a theme role.
  final Color accent;

  /// Lowercase label rendered above the content (labelMedium,
  /// onSurfaceVariant). Omitted entirely when null.
  final String? eyebrow;

  /// Optional 18dp icon leading the eyebrow, tinted to [accent].
  final IconData? eyebrowIcon;

  /// Vertical gap between the eyebrow and the first child.
  final double eyebrowGap;

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  /// The card body, spliced directly into the column below the eyebrow.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final eyebrowStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        // Shrink-wrap for bento cells (unbounded-max height; docs/GRID.md).
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow case final label?) ...[
            if (eyebrowIcon case final icon?)
              Row(
                children: [
                  Icon(icon, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(label, style: eyebrowStyle),
                ],
              )
            else
              Text(label, style: eyebrowStyle),
            SizedBox(height: eyebrowGap),
          ],
          ...children,
        ],
      ),
    );
  }
}
