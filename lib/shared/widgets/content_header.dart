import 'package:flutter/material.dart';

/// In-content title + subtitle that lives at the top of a screen's
/// scrollable body. Scrolls away with the rest of the content — no
/// persistent top chrome.
///
/// Sized so the title sits below the floating back / actions pills
/// (which live ~48 dp into the safe area) without colliding visually.
/// The [topGap] adds vertical space above the title so there's
/// breathing room between the floating chrome and the first text.
class ContentHeader extends StatelessWidget {
  const ContentHeader({
    required this.title,
    this.subtitle,
    this.topGap = 56,
    this.bottomGap = 16,
    this.titleStyle,
    this.subtitleStyle,
    this.subtitleColor,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Space above the title. Defaults to 56 dp — enough to clear the
  /// floating back / actions row that sits ~8 dp into the safe area.
  final double topGap;

  /// Space below the subtitle (or title if no subtitle).
  final double bottomGap;

  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// Convenience override for just the subtitle color — useful for the
  /// flag-first voice on Today / Family Today where the subtitle pivots
  /// to errorContainer-tone when something needs attention.
  final Color? subtitleColor;

  /// Optional widget rendered to the right of the title (e.g. a
  /// status pill or count chip).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = titleStyle ?? theme.textTheme.headlineSmall;
    final baseS = subtitleStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    // Only stomp the color when the caller supplied one — otherwise
    // copyWith(color: null) erases the inherited onSurfaceVariant.
    final s = subtitleColor == null
        ? baseS
        : baseS?.copyWith(color: subtitleColor);
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: bottomGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: s),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
