import 'package:differentworld/shared/breakpoints.dart';
import 'package:flutter/material.dart';

/// The standard scrollable body for any screen that's wider than a
/// single form.
///
/// Wraps the LayoutBuilder + FormFactor + horizontal-padding pattern
/// that until Wave 85 was inlined in two screens (today + family
/// today) and missing from every other screen. After Wave 85, every
/// list-shaped screen wraps its body in this and inherits:
///
/// - **Horizontal padding that scales with width**: 16dp on phones,
///   24dp on tablets, 48dp on desktop windows. Phone screens stay
///   tight; desktop screens get the breathing room expected from a
///   real web app.
/// - **A max content width**: on a 1920-wide window the body doesn't
///   span the full screen — it caps at `maxWidth` (defaults to
///   `Breakpoints.splitMaxWidth` = 1200dp) and centers. Lists at
///   1800dp wide look unfinished.
/// - **Bottom padding for the omnibox bar**: 96dp so the last row
///   isn't obscured by the floating composer.
///
/// Use [children] for list-shaped pages, [slivers] for screens that
/// need sliver primitives (sticky headers, sliver-based grids).
///
/// **Don't** use this for form-shaped pages (single column of fields
/// that should be narrow even on phone). For forms reach for
/// `FormBody` (lib/shared/widgets/form_body.dart) — it clamps to 600dp.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    this.children,
    this.slivers,
    this.itemCount,
    this.itemBuilder,
    this.maxWidth = Breakpoints.splitMaxWidth,
    this.bottomPadding = 96,
    this.physics,
    super.key,
  }) : assert(
          children != null || slivers != null || itemBuilder != null,
          'Provide one of children:, slivers:, or itemBuilder:',
        );

  /// Convenience for `.builder`-shape lists — use when itemCount can
  /// be large enough that materializing every row up front matters.
  /// Pass `itemCount` + `itemBuilder` just like `ListView.builder`.
  const ResponsivePage.builder({
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
    this.maxWidth = Breakpoints.splitMaxWidth,
    this.bottomPadding = 96,
    this.physics,
    super.key,
  })  : children = null,
        slivers = null;

  /// Flat list of widgets — rendered as a `ListView`. Most screens
  /// use this.
  final List<Widget>? children;

  /// Slivers — rendered inside a `CustomScrollView`. Use when the
  /// screen needs sliver-only widgets like `SliverPersistentHeader`
  /// or `SliverAppBar` extensions.
  final List<Widget>? slivers;

  /// `ListView.builder` shape — pass with `itemCount`.
  final IndexedWidgetBuilder? itemBuilder;

  /// Row count when using [itemBuilder].
  final int? itemCount;

  /// Max content width when rendered on wide windows. Defaults to
  /// 1200dp — wider than a form, narrower than a 1920 desktop. Lists
  /// look intentional at this width.
  final double maxWidth;

  /// Reserved at the bottom of the scrollable for the floating
  /// omnibox bar. 96dp matches the `fab-clearance` skill convention.
  final double bottomPadding;

  /// Override for custom scroll physics. Defaults to platform-correct.
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final formFactor = FormFactor.fromWidth(constraints.maxWidth);
        final horiz = switch (formFactor) {
          FormFactor.phone => 16.0,
          FormFactor.smallTablet => 24.0,
          FormFactor.tablet => 24.0,
          FormFactor.desktop => 48.0,
        };
        // Cap the inner column. Otherwise on a 1920 window the
        // content stretches edge-to-edge and looks broken.
        final outerHorizontal = constraints.maxWidth > maxWidth
            ? (constraints.maxWidth - maxWidth) / 2
            : 0.0;
        final padding = EdgeInsets.fromLTRB(
          outerHorizontal + horiz,
          0,
          outerHorizontal + horiz,
          bottomPadding,
        );

        if (slivers != null) {
          return CustomScrollView(
            physics: physics,
            slivers: [
              SliverPadding(
                padding: padding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate(slivers!),
                ),
              ),
            ],
          );
        }
        if (itemBuilder != null) {
          return ListView.builder(
            padding: padding,
            physics: physics,
            itemCount: itemCount,
            itemBuilder: itemBuilder!,
          );
        }
        return ListView(
          padding: padding,
          physics: physics,
          children: children!,
        );
      },
    );
  }
}
