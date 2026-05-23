import 'package:flutter/material.dart';

/// The screen's primary verb — what used to be a FAB. Renders inside
/// the `actions:` row of an EdgeScaffold (top-right pill) with filled
/// emphasis so the user finds it without scanning.
///
/// **Sized to match `IconButton` defaults so it visually aligns with
/// the left-chrome pills (FloatingHamburger / FloatingBack) on the
/// same page**: 24-dp icon + 12-dp padding all sides = 48×48 footprint.
/// Prior versions were intentionally compact (~40×32, 20-dp icon) for
/// internal uniformity within the actions row, but that broke
/// alignment with the hamburger/back chrome on the OTHER side of the
/// page. Wave 26 (2026-05-22) standardized to 48×48 across all chrome.
class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: onPressed == null
            ? scheme.surfaceContainerHighest
            : scheme.primaryContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            // 12dp all sides + 24dp icon = 48dp footprint, matching
            // IconButton default (which the chrome pills use).
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              size: 24,
              color: onPressed == null
                  ? scheme.onSurfaceVariant
                  : scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
