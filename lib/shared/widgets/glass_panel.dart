import 'dart:async';
import 'dart:ui';

import 'package:differentworld/shared/breakpoints.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, SystemChannels;

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

  /// Right-docked side panel — the "third column" a sheet becomes at
  /// desktop widths (the rail | content | panel layout). Full height,
  /// flush against the right viewport edge, rounded on the LEFT edge
  /// only (the other three sit at the window edge). Same blur + alpha
  /// as [sheet] — it's a sheet, just anchored to the side instead of
  /// the bottom. Used by `showGlassSheet` at `>= Breakpoints.tablet`.
  side,
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
      GlassPanelShape.pill => (BorderRadius.circular(24), 18.0, 0.55),
      GlassPanelShape.bar => (BorderRadius.circular(28), 18.0, 0.55),
      GlassPanelShape.sheet => (
        const BorderRadius.vertical(top: Radius.circular(20)),
        22.0,
        0.82,
      ),
      GlassPanelShape.overlay => (BorderRadius.zero, 22.0, 0.78),
      GlassPanelShape.side => (
        const BorderRadius.horizontal(left: Radius.circular(20)),
        22.0,
        0.82,
      ),
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
              border: switch (shape) {
                // Full-screen overlay paints edge-to-edge — no frame.
                GlassPanelShape.overlay => null,
                // The side panel is flush to the top / right / bottom
                // window edges; only the LEFT edge (the one facing the
                // content column) gets the hairline. A full border there
                // would paint invisibly against the OS window chrome.
                GlassPanelShape.side => Border(
                  left: BorderSide(color: border, width: 0.5),
                ),
                _ => Border.all(color: border, width: 0.5),
              },
            ),
            padding: padding ?? EdgeInsets.zero,
            // A transparent Material INSIDE the tinted Container. Ink
            // (ListTile / InkWell splashes) paints on the nearest
            // Material ancestor; without this the nearest one is
            // ABOVE the glass fill, so every ripple in a glass sheet
            // renders *behind* the tint and is invisible. Flutter
            // 3.47 asserts on exactly this. `_SidePanelFrame` already
            // did it by hand — hoisting it here fixes every shape
            // (pill / bar / sheet / overlay / side) in one place.
            child: Material(type: MaterialType.transparency, child: child),
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
  // Wave 107: at tablet+ widths route through a centered dialog
  // instead of a bottom sheet. Pinning a 3-row picker to the
  // bottom of a 1080p window is the single biggest "this is a
  // phone app" tell. Opt-out is `dialogAtDesktop: false` for
  // sheets that genuinely need the bottom anchor (e.g. one-handed
  // gestural pickers).
  bool dialogAtDesktop = true,
  double dialogMaxWidth = 480,
  // Wave 180: at true desktop widths a sheet docks as a right-side
  // glass panel — the third column of the rail | content | panel
  // layout — sliding in over the (still-visible) page. Width of that
  // panel; clamped at runtime so it never eats more than half the
  // window.
  double sidePanelWidth = 460,
}) {
  final width = MediaQuery.sizeOf(context).width;
  // ≥ tablet (1200): the desktop three-column world. The nav rail is
  // already a persistent left column here, so a sheet becomes a
  // persistent-feeling right column. It stays a real Navigator route,
  // so the `Future<T?>` / `Navigator.pop(result)` contract every
  // picker relies on is unchanged — no call site changes.
  if (dialogAtDesktop && width >= Breakpoints.tablet) {
    return _showGlassSidePanel<T>(
      context: context,
      builder: builder,
      isDismissible: isDismissible,
      panelWidth: sidePanelWidth,
    );
  }
  // 840–1200 (small tablet / phone landscape): centered dialog. A
  // bottom sheet reads as "phone app" but there isn't room for a
  // comfortable third column yet.
  if (dialogAtDesktop && width >= Breakpoints.smallTablet) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      builder: (ctx) => Dialog(
        // Transparent + zero-elevation so the GlassPanel inside is
        // the only visible surface — matches the sheet path.
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dialogMaxWidth),
          child: GlassPanel(
            child: GlassSheetScope(
              surface: GlassSheetSurface.dialog,
              child: builder(ctx),
            ),
          ),
        ),
      ),
    );
  }
  // < 840 (phone): the bottom sheet, as ever.
  return showModalBottomSheet<T>(
    context: context,
    // Root navigator so the sheet renders ABOVE the AppShell chrome. On the
    // nested shell navigator (the default), a tall `isScrollControlled` sheet
    // extends up THROUGH the floating top-chrome pills, which paint over its
    // top (title / drag handle / first field get half-hidden). The dialog +
    // side-panel branches already use the root navigator (showDialog /
    // showGeneralDialog default to it); this aligns the bottom sheet with them.
    useRootNavigator: true,
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
      child: GlassSheetScope(
        surface: GlassSheetSurface.bottomSheet,
        child: builder(ctx),
      ),
    ),
  );
}

/// The desktop "third panel": a right-docked, full-height glass panel
/// that slides in from the right edge over the (still-visible) page.
///
/// Implemented as a [showGeneralDialog] route — NOT a layout column —
/// on purpose:
///   * It stays a Navigator route, so `Navigator.pop(result)` resolves
///     the returned `Future<T?>` exactly like the bottom-sheet path.
///     Every `await pickSubject(...)` / `await showGlassSheet(...)`
///     keeps working with zero call-site changes.
///   * The barrier is deliberately light (0.30 black — the same weight
///     as the omnibox suggestion overlay) so the page behind stays
///     clearly visible: the panel reads as a docked third column, not a
///     modal that blacks out the app.
///
/// The body is given a BOUNDED full height and top-aligned. That's
/// what lets the bottom-sheet-era bodies (built with `mainAxisSize.min`,
/// `Expanded` lists, and `maxHeight: 0.7 * screenHeight` caps) re-host
/// here without layout asserts: `Expanded` needs a finite incoming
/// max-height, which a full-height [Expanded] gives it; short bodies
/// simply sit at the top with glass below.
Future<T?> _showGlassSidePanel<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool isDismissible,
  required double panelWidth,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    // A non-empty label is required whenever barrierDismissible is true.
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.30),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      final w = MediaQuery.sizeOf(ctx).width;
      // Never let the panel eat more than half the window, and keep a
      // sane floor on a narrow desktop window.
      final resolved = panelWidth.clamp(320.0, w * 0.5);
      // `.drive(...CurveTween...)` rather than a `CurvedAnimation` object so
      // there's no listener-bearing animation to dispose — the chained
      // tween is stateless and rides the route's own animation lifecycle.
      final slide = animation.drive(
        Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
      );
      return Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: slide,
          child: SizedBox(
            width: resolved,
            height: double.infinity,
            child: _SidePanelFrame(
              isDismissible: isDismissible,
              builder: builder,
            ),
          ),
        ),
      );
    },
  );
}

/// Chrome for the desktop side panel: the glass surface, a slim
/// top strip carrying a close button (only when dismissible), and the
/// body below — bounded, top-aligned, scroll-safe.
class _SidePanelFrame extends StatefulWidget {
  const _SidePanelFrame({
    required this.builder,
    required this.isDismissible,
  });

  final WidgetBuilder builder;
  final bool isDismissible;

  @override
  State<_SidePanelFrame> createState() => _SidePanelFrameState();
}

class _SidePanelFrameState extends State<_SidePanelFrame> {
  /// The route's entry animation — we raise the IME only once it COMPLETES.
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // showGeneralDialog (unlike the Dialog widget the 840–1200 path uses)
    // installs no FocusTrap, so on a touch device the engine can skip raising
    // the soft keyboard for a body's `autofocus: true` TextField. Nudge it —
    // but only AFTER the slide-in finishes. Firing on the first frame (mid-
    // animation) is too early: the autofocus field hasn't established its
    // TextInputConnection yet, so `TextInput.show` would no-op and the
    // keyboard would never appear on slower hardware. Fire on
    // AnimationStatus.completed instead.
    final anim = ModalRoute.of(context)?.animation;
    if (identical(anim, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    _routeAnimation = anim;
    if (anim == null || anim.isCompleted) {
      _showKeyboard();
    } else {
      anim.addStatusListener(_onRouteAnimation);
    }
  }

  void _onRouteAnimation(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    _showKeyboard();
  }

  /// Raise the soft keyboard for whatever holds the input connection. Safe to
  /// fire unconditionally — it's a documented no-op when nothing has a
  /// connection (a picker with no text field, or a hardware keyboard).
  void _showKeyboard() {
    if (!mounted) return;
    unawaited(SystemChannels.textInput.invokeMethod('TextInput.show'));
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimation);
    super.dispose();
  }

  /// Dismiss through `maybePop`, NOT `pop` — `maybePop` routes through any
  /// `PopScope` in the body (e.g. `DismissGuard`), so the close button and
  /// Esc honour the "Discard changes?" guard on dirty forms instead of
  /// silently discarding typed-in work. A direct `pop` would skip PopScope.
  void _close() {
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final panel = GlassPanel(
      shape: GlassPanelShape.side,
      // showGeneralDialog (unlike showModalBottomSheet / Dialog) provides
      // NO Material ancestor, but the re-hosted bodies use ListTile /
      // InkWell / TextField, which require one. A transparent Material
      // gives them the ink + text services without painting a surface
      // over the glass. Inside the GlassPanel so its ClipRRect clips ink
      // splashes to the rounded panel.
      child: Material(
        type: MaterialType.transparency,
        // Keep the top / right / bottom insets (status bar; home indicator
        // at the right edge in landscape). Only the LEFT edge faces the
        // content column, where no system inset applies.
        child: SafeArea(
          left: false,
          child: Column(
            children: [
              // Slim chrome strip. Only carries the close affordance when
              // the sheet is dismissible; a non-dismissible sheet must
              // pop itself from its own actions, same as a bottom sheet.
              if (widget.isDismissible)
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).closeButtonTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: _close,
                      ),
                    ],
                  ),
                ),
              // Body. Expanded gives it a finite height so in-body
              // `Expanded`/`ListView` resolve; Align tops it so short
              // bodies don't stretch awkwardly down the panel. The scope
              // marks this as a docked surface so bottom-sheet affordances
              // (a `GlassDragHandle`) self-suppress here.
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: GlassSheetScope(
                    surface: GlassSheetSurface.sidePanel,
                    child: Builder(builder: widget.builder),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Esc closes (when dismissible) — desktop/web users expect it. Routed
    // through _close → maybePop so DismissGuard still fires. The body's own
    // autofocus still wins focus; this shortcut fires because the focused
    // body element sits inside this subtree and a TextField doesn't consume
    // Escape.
    if (!widget.isDismissible) return panel;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: panel,
    );
  }
}

/// Which surface a glass sheet body is currently being hosted in.
/// `showGlassSheet` picks the surface by viewport width; bodies read it
/// (via [GlassSheetScope]) to adapt affordances that only make sense in
/// one shape — chiefly the drag-handle pill, which means nothing in a
/// right-docked panel or a centered dialog.
enum GlassSheetSurface { bottomSheet, dialog, sidePanel }

/// Tells a sheet body which surface it's rendered in. Provided by
/// `showGlassSheet` around every body; read with [GlassSheetScope.of].
/// Defaults to [GlassSheetSurface.bottomSheet] when absent so a body
/// shown outside the helper behaves like a plain sheet.
class GlassSheetScope extends InheritedWidget {
  const GlassSheetScope({
    required this.surface,
    required super.child,
    super.key,
  });

  final GlassSheetSurface surface;

  static GlassSheetSurface of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GlassSheetScope>();
    return scope?.surface ?? GlassSheetSurface.bottomSheet;
  }

  @override
  bool updateShouldNotify(GlassSheetScope oldWidget) =>
      oldWidget.surface != surface;
}

/// The little grey grab-pill at the top of a bottom sheet. Use this
/// instead of hand-rolling a `Container(width: 36, height: 4, …)` so it
/// renders ONLY where a drag gesture exists — it collapses to nothing in
/// a centered dialog or a right-docked side panel, where there's nothing
/// to drag and a stray pill reads as a layout artifact.
class GlassDragHandle extends StatelessWidget {
  const GlassDragHandle({this.bottomMargin = 12, super.key});

  /// Gap below the pill before the body's first row. Matches whatever the
  /// hand-rolled pill used at each call site.
  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    // Only a bottom sheet can be dragged — suppress everywhere else.
    if (GlassSheetScope.of(context) != GlassSheetSurface.bottomSheet) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: EdgeInsets.only(bottom: bottomMargin),
        decoration: BoxDecoration(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
