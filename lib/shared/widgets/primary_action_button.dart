import 'package:flutter/material.dart';

/// The screen's primary verb — what used to be a FAB. Renders inside
/// the `actions:` row of an EdgeScaffold (top-right pill) with filled
/// emphasis so the user finds it without scanning. Secondary actions
/// stay as plain IconButtons next to it.
///
/// Why this exists rather than a plain `IconButton.filled`:
///
///   - Padding tuned for the GlassPill row (filled icon buttons
///     default to 8 dp padding; we want them snug so the pill stays
///     compact).
///   - Tooltip is mandatory — primary verbs without a label depend
///     on iconography alone, which fails for new users.
///   - One consistent visual across every screen, so the user learns
///     "the filled button is the main thing" once.
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
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            child: Icon(
              icon,
              size: 20,
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
