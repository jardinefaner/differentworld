import 'dart:ui';

import 'package:flutter/material.dart';

/// Shapes the [GlassPanel] knows how to render. Pick the one that
/// matches the surface — the shape determines border radius, blur
/// strength, and tint alpha so the panel reads correctly in
/// context.
enum GlassPanelShape {
  /// Small floating chrome — hamburger / back / actions pill. Pill-
  /// shaped, light blur, slightly more solid so 1-3 icons stay
  /// readable. Use via the existing `GlassPill` widget (kept for
  /// callers; eventually delegates here for consistency).
  pill,

  /// Full-width floating bar — the bottom omnibox composer. Rounded
  /// on all corners; moderate blur; translucent enough to show the
  /// page content scrolling underneath.
  bar,

  /// Modal sheet — bottom sheet, drawer panel. Top-rounded;
  /// stronger blur because the panel covers a large portion of the
  /// page; slightly more solid alpha so list rows / form fields
  /// stay readable.
  sheet,

  /// Full-screen overlay panel — omnibox suggestion list, full-
  /// height confirm sheets. No rounding (it covers the chrome
  /// reservation area edge-to-edge); strong blur; most solid alpha
  /// so the dense content is clearly the focus.
  overlay,
}

/// The shared glass-frost surface used by every floating chrome
/// element in the app. Wraps content in a `BackdropFilter` plus a
/// translucent tinted container so the page content behind it is
/// visible through the blur. One widget — many shapes — keeps the
/// chrome system visually consistent.
///
/// Conventions:
///   * Top chrome pills (`GlassPill`) use [GlassPanelShape.pill].
///   * Bottom omnibox bar uses [GlassPanelShape.bar].
///   * Modal bottom sheets opt into glass via `showGlassSheet`,
///     which wraps the body in `[GlassPanelShape.sheet]`.
///   * Drawer (`MainDrawer`) wraps its body in
///     `[GlassPanelShape.sheet]` so the staff drawer matches the
///     same vocabulary.
///   * Full-screen overlays (omnibox suggestion panel) use
///     `[GlassPanelShape.overlay]`.
///
/// Avoid extending the shape catalog without a clear visual case;
/// every shape is one more thing that has to stay aesthetically
/// consistent.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.shape = GlassPanelShape.sheet,
    this.padding,
    super.key,
  });

  final Widget child;
  final GlassPanelShape shape;

  /// Optional padding inside the panel — defaults to zero. Pills
  /// pass their own 0 padding because they're sized by their
  /// children's intrinsic dimensions.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final border = scheme.outlineVariant.withValues(alpha: 0.4);
    final (radius, blur, alpha) = switch (shape) {
      GlassPanelShape.pill =>
        (BorderRadius.circular(24), 18.0, 0.55),
      GlassPanelShape.bar =>
        (BorderRadius.circular(28), 18.0, 0.55),
      GlassPanelShape.sheet =>
        (const BorderRadius.vertical(top: Radius.circular(20)), 22.0, 0.82),
      GlassPanelShape.overlay =>
        (BorderRadius.zero, 22.0, 0.78),
    };

    // RepaintBoundary so the blur is rasterised once and cached
    // across parent rebuilds. BackdropFilter is one of the most
    // expensive operations in the Impeller pipeline; we keep it
    // small and re-usable.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: alpha),
              borderRadius: radius,
              border: shape == GlassPanelShape.overlay
                  ? null
                  : Border.all(color: border, width: 0.5),
            ),
            padding: padding ?? EdgeInsets.zero,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Opens a modal bottom sheet whose body is wrapped in
/// [GlassPanel] for the glass-frost chrome look. Use instead of
/// `showModalBottomSheet` whenever a sheet should match the
/// floating-chrome language.
///
/// Pass `child` exactly the way you'd pass `builder(ctx)` to
/// `showModalBottomSheet` — minus the outer Material / Container.
/// The glass panel provides the surface; padding inside the child
/// is the caller's choice.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = false,
  bool useSafeArea = true,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    // Transparent background so the GlassPanel inside is the only
    // surface — without this, Flutter's default sheet background
    // would render BEHIND the glass and defeat the blur.
    backgroundColor: Colors.transparent,
    // Same — drop the shadow so the glass appears to float rather
    // than sit on a darker stage.
    elevation: 0,
    builder: (ctx) => GlassPanel(
      child: builder(ctx),
    ),
  );
}
