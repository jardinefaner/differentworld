import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/settings/display_style_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-content title + subtitle that lives at the top of a screen's
/// scrollable body. Scrolls away with the rest of the content — no
/// persistent top chrome.
///
/// **Chrome clearance** is automatic: EdgeScaffold publishes the
/// floating-chrome band into the body's `MediaQuery.padding.top`, so
/// this header (like any `SafeArea`) simply honours that inset and
/// starts below the pills. No per-screen `topChromeHeight` math — the
/// reservation can't be forgotten, because it lives in the scaffold,
/// not in each screen's first child.
///
/// The body is still NOT wrapped in a SafeArea by EdgeScaffold — that
/// would paint a solid scaffold-coloured strip behind the chrome (the
/// "appbar background color" complaint) and stop content from scrolling
/// under the glass. The header reserves only the inset; the content
/// scrolls under the translucent pills as it moves up.
///
/// [topGap] stays as the breathing room ABOVE the title (between
/// the chrome edge and the first text). Set to 0 if a screen wants
/// the title flush against the chrome boundary.
class ContentHeader extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = titleStyle ?? theme.textTheme.headlineSmall;
    // Clean display style → sentence-case titles (the mockup voice); Calm /
    // Boxed keep the brand's UPPERCASE tracked hero.
    final clean = ref.watch(displayStyleProvider).value == DisplayStyle.clean;
    final baseS = subtitleStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    // Only stomp the color when the caller supplied one — otherwise
    // copyWith(color: null) erases the inherited onSurfaceVariant.
    final s = subtitleColor == null
        ? baseS
        : baseS?.copyWith(color: subtitleColor);
    // Chrome clearance. EdgeScaffold publishes the floating-chrome band
    // into `MediaQuery.padding.top`, so the status bar + chrome pill row
    // are BOTH already in this inset — we just honour it (`topGap` stacks
    // on top as breathing room). Used outside the shell (no EdgeScaffold
    // ancestor → no injection), this is just the status bar, still right.
    final chromeReservation = MediaQuery.paddingOf(context).top;
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
                // Hero treatment: tracked uppercase (the brand voice). The
                // display string is capped; `semanticsLabel` keeps the
                // original case so screen readers don't spell it out.
                if (clean)
                  Text(title, style: t)
                else
                  Text(
                    title.toUpperCase(),
                    semanticsLabel: title,
                    style: t?.copyWith(letterSpacing: AppType.tracking),
                  ),
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
