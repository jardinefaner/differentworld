import 'package:flutter/material.dart';

/// The Calm "one left edge" **row** — a flat, fill-less line of content with
/// a 2dp rule down its left side (docs/BRAND.md law 1).
///
/// Distinct from `AccentEdgeCard`, which is the same idea at panel weight: a
/// filled `surfaceContainerHighest` block with a 4dp edge and rounded right
/// corners. Use the CARD when the thing is a self-contained object you could
/// tap into; use this ROW when it is one item in a list and the edge is
/// doing the grouping. Reaching for a card where a row belongs is what
/// produces the boxed cards-within-cards the brand law exists to prevent.
///
/// This exists because the pattern was hand-rolled 21 times across 10 files
/// — `Container(decoration: BoxDecoration(border: Border(left: BorderSide(…`
/// — each one re-deciding the width, the padding and the disabled colour.
/// A law enforced by copy-paste is a law that drifts.
///
/// The [accent] is optional: null gives the neutral `outlineVariant` rule
/// that means "an item", while a colour means "an item with a state" (a
/// repeat, a breach, someone leaving). That is the whole vocabulary — the
/// edge carries the signal, so the row itself never needs a fill or a badge.
class AccentEdgeRow extends StatelessWidget {
  const AccentEdgeRow({
    this.title,
    this.subtitle,
    this.accent,
    this.subtitleColor,
    this.trailing,
    this.onTap,
    this.child,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsets.only(left: 12),
    super.key,
  }) : assert(
         child != null || title != null,
         'Give AccentEdgeRow a title or a child',
       );

  /// The line you read first. Omitted when [child] is supplied.
  final String? title;

  /// The line under it — the *why*, not a repeat of the title.
  final String? subtitle;

  /// Left-rule colour. Null = the neutral `outlineVariant` rule.
  final Color? accent;

  /// Colour for [subtitle]. Defaults to `onSurfaceVariant`; pass [accent]
  /// when the subtitle is explaining the state the edge is signalling.
  final Color? subtitleColor;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// Escape hatch for rows whose body is not title+subtitle. Supplying this
  /// ignores [title] / [subtitle] / [trailing].
  final Widget? child;

  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body =
        child ??
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title!, style: theme.textTheme.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            subtitleColor ?? theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        );

    final decorated = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            width: 2,
            color: accent ?? theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: body,
    );

    // No InkWell when there is nothing to tap — an inkwell on a static row
    // promises an interaction the hand then does not get.
    if (onTap == null) return decorated;
    return InkWell(onTap: onTap, child: decorated);
  }
}
