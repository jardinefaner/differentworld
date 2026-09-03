import 'package:flutter/material.dart';

/// Tone for a [SectionCard] — drives the surface color so a section
/// that's flagging something for attention reads differently from a
/// calm aggregator. Matches `FeatureCardTone`'s vocabulary so a screen
/// composed of cards + sections feels visually unified.
enum SectionCardTone {
  /// Default — `surfaceContainerHighest`. Use for calm sections that
  /// don't carry urgency.
  neutral,

  /// Featured / primary — `primaryContainer` at 0.45 alpha. Use for
  /// "this needs your attention" sections that aren't an emergency —
  /// unread messages, pending tasks.
  featured,

  /// Danger — `errorContainer` at 0.45 alpha. Use for "something is
  /// wrong" sections — overdue certs, flagged kids, sync errors.
  danger,

  /// Success — `tertiaryContainer` at 0.5 alpha. Use sparingly; an
  /// "all clear" section that warrants celebration.
  success,
}

/// Aggregator section that shows a heading + body, and **hides
/// itself when there's nothing to show**.
///
/// This is the shape Today's "Unread messages", "Director pulse",
/// "Top insight", and "Leading today" cards all reinvented. The
/// pattern is: a feature watches some data; if the data is empty,
/// the section returns `SizedBox.shrink()` instead of rendering an
/// empty card. The screen composes a vertical list of these and
/// each one self-decides whether to take up scroll.
///
/// **The hide-when-empty contract**: pass [visible] = false (or
/// don't include a body) and the section collapses entirely — no
/// heading, no padding, no gap. The screen's column doesn't even
/// see the section.
///
/// **Examples**:
///
/// Simple unread-messages section:
/// ```dart
/// SectionCard(
///   visible: unreadCount > 0,
///   icon: Icons.mark_chat_unread_outlined,
///   title: '$unreadCount unread messages',
///   tone: SectionCardTone.featured,
///   child: Column(children: [ for (final t in threads) ThreadRow(t) ]),
/// )
/// ```
///
/// With a trailing "+N more" chip:
/// ```dart
/// SectionCard(
///   visible: threads.isNotEmpty,
///   icon: Icons.forum_outlined,
///   title: 'Conversations',
///   trailing: Text('+${threads.length - visible.length}'),
///   child: ...,
/// )
/// ```
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.tone = SectionCardTone.neutral,
    this.visible = true,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 4),
    this.borderRadius = 14,
    this.bottomGap = 16,
    super.key,
  });

  /// Optional icon shown to the left of the title.
  final IconData? icon;

  /// Section heading — typically a String for the simple case; pass a
  /// Widget when you need richer layout (e.g. title + timestamp row).
  final Object title;

  /// Optional trailing widget rendered at the end of the heading row
  /// — count badge, "+N more" hint, dismiss button.
  final Widget? trailing;

  /// The body content. Typically a [Column] of rows, but anything
  /// goes — a chart, a single Text, a horizontal scroll.
  final Widget child;

  final SectionCardTone tone;

  /// When false the entire section collapses to a zero-height
  /// `SizedBox.shrink()` — no card, no heading, no padding, no
  /// gap-below. The Today/Family columns are composed of sections
  /// that self-hide.
  final bool visible;

  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Spacer rendered BELOW the section when [visible] is true.
  /// Sections live in a [Column], so each one owns its trailing gap
  /// — the column doesn't need to interleave `SizedBox(height: 16)`
  /// between sections.
  final double bottomGap;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(borderRadius);
    final bg = switch (tone) {
      SectionCardTone.neutral => scheme.surfaceContainerHighest,
      SectionCardTone.featured => scheme.primaryContainer.withValues(
        alpha: 0.45,
      ),
      SectionCardTone.danger => scheme.errorContainer.withValues(alpha: 0.45),
      SectionCardTone.success => scheme.tertiaryContainer.withValues(
        alpha: 0.5,
      ),
    };
    final onContainer = switch (tone) {
      SectionCardTone.neutral => scheme.onSurface,
      SectionCardTone.featured => scheme.onPrimaryContainer,
      SectionCardTone.danger => scheme.onErrorContainer,
      SectionCardTone.success => scheme.onTertiaryContainer,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: Material(
        color: bg,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: padding,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: onContainer),
                    const SizedBox(width: 8),
                  ],
                  Expanded(child: _renderTitle(theme, onContainer)),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    // Flexible, not bare: the title is Expanded but a trailing
                    // action was laid out at its intrinsic width, so a labelled
                    // button at 200% text pushed the header 149px off the right
                    // edge. Both sides can give now.
                    Flexible(child: trailing!),
                  ],
                ],
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _renderTitle(ThemeData theme, Color onContainer) {
    if (title is Widget) return title as Widget;
    return Text(
      title as String,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: onContainer,
      ),
    );
  }
}
