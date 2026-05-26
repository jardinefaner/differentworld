import 'package:differentworld/shared/breakpoints.dart';
import 'package:flutter/material.dart';

/// A list/grid that switches its column count by form factor.
///
/// Wave 110. The desktop audit's "list-of-cards on a 1920px screen
/// looks lonely" finding — every list-shaped screen used to render
/// a single column of stretched cards even at desktop widths. This
/// widget renders:
///
/// - `1` column on phone (`< 840dp`) — same as before
/// - `2` columns on tablet (`840dp – 1200dp`)
/// - `3` columns on desktop (`>= 1200dp`)
///
/// The number per breakpoint is configurable. Card height is driven
/// by the items themselves; the widget uses `SliverGrid` with a
/// `SliverGridDelegateWithMaxCrossAxisExtent` so cards reflow
/// naturally as the viewport resizes.
///
/// **When to use this vs. a plain ListView**:
///
/// - Use when each item is a self-contained card (vehicle, classroom,
///   capture, kid card). The card knows its own height; siblings
///   don't depend on each other.
/// - Use when the list could plausibly be a wall of tiles in a real
///   product. Roster, vehicle fleet, photo gallery, survey roster.
///
/// **When NOT to use**:
///
/// - Lists where each row is wide-and-short (an attendance row with
///   inline status buttons; a message thread bubble). Those want
///   the full content width.
/// - Lists where item order is critical and grid reflow would
///   confuse the user (an inbox feed where newest-first scrolls
///   downward, not zig-zag).
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.itemMaxWidth = 480,
    this.spacing = 12,
    this.aspectRatio = 1.6,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    super.key,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// Maximum cross-axis (horizontal) extent for a single card. The
  /// grid packs as many columns as fit within the viewport at this
  /// max-width; on phone (<480 effective) it falls back to a single
  /// column.
  final double itemMaxWidth;

  /// Spacing between cards (both axes).
  final double spacing;

  /// Card aspect ratio (width / height). 1.6 = a slightly wide
  /// rectangle — works for most card-shaped content. Override for
  /// taller cards (e.g. photo-heavy tiles).
  final double aspectRatio;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: padding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: itemMaxWidth,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Sliver flavor for use inside a `CustomScrollView`. Same shape as
/// [ResponsiveGrid] but returns a `SliverGrid` so callers can compose
/// with other slivers.
class SliverResponsiveGrid extends StatelessWidget {
  const SliverResponsiveGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.itemMaxWidth = 480,
    this.spacing = 12,
    this.aspectRatio = 1.6,
    super.key,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final double itemMaxWidth;
  final double spacing;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: itemMaxWidth,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// Helper: returns the number of columns that would render at the
/// current viewport. Useful when a caller needs to make decisions
/// (e.g. spread headers across columns).
int responsiveColumnsAt(BuildContext context, {double itemMaxWidth = 480}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < Breakpoints.smallTablet) return 1;
  return (width / itemMaxWidth).floor().clamp(1, 4);
}
