import 'package:differentworld/shared/widgets/shell_metrics.dart';
import 'package:flutter/material.dart';

/// In-content title + subtitle that lives at the top of a screen's
/// scrollable body. Scrolls away with the rest of the content — no
/// persistent top chrome.
///
/// **Chrome clearance** is reserved by THIS widget when it's the
/// first item in the scrollable (which is the convention across
/// every screen). EdgeScaffold no longer pads the body for chrome —
/// the body extends fully edge-to-edge, the chrome pills float as
/// translucent glass overlays. To keep the title from sitting
/// behind the chrome on initial paint, ContentHeader reserves the
/// status bar inset + chrome pill row internally.
///
/// Wave 53 made this the single place that knows about chrome — the
/// EdgeScaffold's old SafeArea wrapper was removed because layering
/// it on top of this reservation produced a solid-coloured strip
/// (the "appbar background color" the user reported).
///
/// [topGap] stays as the breathing room ABOVE the title (between
/// the chrome edge and the first text). Set to 0 if a screen wants
/// the title flush against the chrome boundary.
class ContentHeader extends StatelessWidget {
  const ContentHeader({
    required this.title,
    this.subtitle,
    this.topGap = 8,
    this.bottomGap = 16,
    this.titleStyle,
    this.subtitleStyle,
    this.subtitleColor,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Breathing room above the title. Default 8 dp — the shell already
  /// reserves the chrome height; this is just visual gap. Set to 0 if
  /// a screen explicitly wants the title flush against the chrome
  /// boundary.
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
    // Chrome clearance — Wave 52. The status bar height plus the
    // floating-chrome pill row are added so the title doesn't render
    // behind either. `topGap` stacks on top as breathing room.
    final topInset = MediaQuery.paddingOf(context).top;
    final chromeReservation = topInset + ShellMetrics.topChromeHeight;
    return Padding(
      padding: EdgeInsets.only(
        top: chromeReservation + topGap,
        bottom: bottomGap,
      ),
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
