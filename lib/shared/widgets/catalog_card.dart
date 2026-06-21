import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A responsive **catalog grid** — a non-scrolling [Wrap] of equal-width cards
/// that re-packs from 1 column (phone) to as many as fit ([minTileWidth]) at
/// width. Compose it inside a scrolling body (ResponsivePage / a Column in a
/// SingleChildScrollView) with the page header above it — the Wrap sizes each
/// card to its own content, so variable card heights never clip (unlike a
/// fixed-aspect GridView). The shared shape for every library browse surface
/// (missions, activities, heroes, world book, themed worlds).
class CatalogGrid extends StatelessWidget {
  const CatalogGrid({
    required this.children,
    this.minTileWidth = 168,
    this.spacing = 12,
    this.maxColumns = 4,
    super.key,
  });

  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = (w / minTileWidth).floor().clamp(1, maxColumns);
        final tileWidth = cols == 1 ? w : (w - (cols - 1) * spacing) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

/// One browse card in a [CatalogGrid] — a [leading] icon chip, a [title], an
/// optional one-line [subtitle], and a row of [chips]. Flat themed surface,
/// tappable. Content shrink-wraps (no Expanded/Spacer), so it's safe in the
/// Wrap cell. Replaces the flat `ListTile` row on browse/library screens.
class CatalogCard extends StatelessWidget {
  const CatalogCard({
    required this.leading,
    required this.title,
    this.titleWidget,
    this.onTap,
    this.subtitle,
    this.chips = const [],
    super.key,
  });

  final Widget leading;
  final String title;

  /// Optional widget rendered IN PLACE of [title] — e.g. an `EntityLink` so the
  /// name peeks. [title] stays required as the plain-text label + a11y
  /// fallback. Keeps this shared primitive entity-agnostic: the call-site (in a
  /// feature) builds the widget.
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget> chips;

  /// Tap handler. Null → a display-only card (no ink, no haptic) for browse
  /// surfaces whose items have no detail destination (e.g. the world book).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sub = subtitle;
    final tap = onTap;
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(height: 10),
          titleWidget ??
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          if (sub != null && sub.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              sub,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 11),
            Wrap(spacing: 6, runSpacing: 6, children: chips),
          ],
        ],
      ),
    );
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: tap == null
          ? content
          : InkWell(
              onTap: () {
                unawaited(HapticFeedback.selectionClick());
                tap();
              },
              child: content,
            ),
    );
  }
}

/// The rounded leading chip for a [CatalogCard] — an emoji glyph or a themed
/// icon on a soft surface tint.
class CatalogIcon extends StatelessWidget {
  const CatalogIcon.emoji(this.emoji, {super.key}) : icon = null;
  const CatalogIcon.icon(this.icon, {super.key}) : emoji = null;

  final String? emoji;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: emoji != null
          ? Text(emoji!, style: const TextStyle(fontSize: 24))
          : Icon(icon, size: 22, color: scheme.onSurfaceVariant),
    );
  }
}

/// A small pill for a [CatalogCard]'s chip row. [background] tints it (a
/// content/category accent); omitted → a neutral surface chip. Pass the
/// matching on-tone [foreground] so contrast holds in light + dark.
class CatalogChip extends StatelessWidget {
  const CatalogChip(this.label, {this.background, this.foreground, super.key});

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: foreground ?? scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
