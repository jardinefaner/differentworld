import 'package:flutter/material.dart';

/// Companion to `PrimaryActionButton` for secondary verbs in the
/// chrome pill row — same height + padding + icon size as the
/// primary, but no filled background so the primary still pops via
/// color and fill rather than size.
///
/// Why this exists: before Wave 18, secondary chrome actions used a
/// raw `IconButton` which renders at Material's default 48×48 with a
/// 24-dp icon. PrimaryActionButton is intentionally compact at ~40×32
/// with a 20-dp icon. Mixing both in the same `actions:` row looked
/// mismatched ("why are these different sizes?"). Normalizing
/// secondary actions to the same footprint as primary keeps the row
/// visually uniform; primary stays distinct via fill + tint.
///
/// Use in `EdgeScaffold(actions: [...])` slots wherever a chrome
/// action was previously a bare `IconButton`. Sync indicators, edit
/// chips, dismiss-selection icons, etc.
class SecondaryActionButton extends StatelessWidget {
  const SecondaryActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  /// Override the icon tint (e.g., error red for "Offline" sync
  /// indicator). Defaults to `onSurfaceVariant` for the standard
  /// secondary look.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null;
    final tint = iconColor ??
        (disabled ? scheme.onSurfaceVariant : scheme.onSurfaceVariant);
    return Tooltip(
      message: tooltip,
      child: Material(
        // Transparent — the primary action carries the fill; this
        // sits as a quieter icon-only pill next to it. InkWell still
        // shows a ripple on tap for affordance.
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            // Match PrimaryActionButton exactly so heights line up
            // in the GlassPill row.
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            child: Icon(
              icon,
              size: 20,
              color: tint,
            ),
          ),
        ),
      ),
    );
  }
}
