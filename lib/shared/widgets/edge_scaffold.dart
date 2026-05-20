import 'dart:async';

import 'package:differentworld/shared/widgets/route_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The replacement for `Scaffold` + `AppBar` across the app.
///
/// - No persistent top chrome rendered inside the route — chrome
///   (back button, action pill, top overlay) is hoisted into the
///   AppShell layer via [routeChromeProvider]. EdgeScaffold's job is
///   just to publish its chrome props to that provider so AppShell
///   can paint them over the page transition without sliding them.
/// - Content fills the screen edge-to-edge.
/// - The [body] is wrapped in a `SafeArea` so first-row content sits
///   below the status bar; the bottom is intentionally NOT wrapped so
///   content can scroll under the gesture indicator.
/// - [floatingActionButton] and [bottomSheet] pass through to a
///   real `Scaffold` underneath.
///
/// Title / subtitle live INSIDE [body] as the first scrollable
/// content via `ContentHeader` — not in chrome. That's the whole
/// point of the redesign.
class EdgeScaffold extends ConsumerStatefulWidget {
  const EdgeScaffold({
    required this.body,
    this.actions = const <Widget>[],
    this.showBack = true,
    this.backFallbackRoute = '/',
    this.drawer,
    this.topOverlay,
    this.floatingActionButton,
    this.bottomSheet,
    this.resizeToAvoidBottomInset,
    this.includeSearchAction = false,
    super.key,
  });

  final Widget body;

  /// Screen-specific actions for the top-right pill. Published to
  /// [routeChromeProvider] in initState; AppShell renders them.
  final List<Widget> actions;

  /// **Deprecated** — the persistent bottom omnibox bar in AppShell
  /// is now the canonical search affordance. Defaults to false. Kept
  /// in the API for source compatibility while the call sites are
  /// audited; it no longer renders anything.
  final bool includeSearchAction;

  /// When true (default), the top-left shows the FloatingBack pill.
  /// When false, no back button (home screens).
  final bool showBack;
  final String backFallbackRoute;

  /// Optional left-side drawer. Drawer ownership stays on the route's
  /// Scaffold (not the AppShell's), because Flutter's drawer requires
  /// a Scaffold ancestor and the drawer scrim should cover JUST this
  /// route's body, not the AppShell's omnibox bar.
  final Widget? drawer;

  /// When non-null, replaces both the left and right chrome with a
  /// single full-width overlay. Published to the chrome provider so
  /// AppShell paints it at the same Y-position as the floating
  /// back/actions would be.
  final Widget? topOverlay;

  final Widget? floatingActionButton;
  final Widget? bottomSheet;
  final bool? resizeToAvoidBottomInset;

  @override
  ConsumerState<EdgeScaffold> createState() => _EdgeScaffoldState();
}

class _EdgeScaffoldState extends ConsumerState<EdgeScaffold> {
  /// Per-instance opaque key. Identifies THIS EdgeScaffold's chrome
  /// entry on the stack so pop() in dispose removes the right one
  /// (and push() in didUpdateWidget updates in place rather than
  /// stacking duplicates).
  ///
  /// `identityHashCode(this)` is unique-per-instance for the life
  /// of the State object, which matches our lifecycle exactly.
  late final Object _chromeKey = identityHashCode(this);

  /// Cached notifier handle. We grab it in initState because
  /// `ref.read` is unsafe in dispose (the element is deactivated by
  /// then) — having a non-null handle here lets pop() run after
  /// dispose without touching the ref.
  RouteChromeNotifier? _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(routeChromeProvider.notifier);
    // Defer the first publish — initState fires DURING the widget
    // tree's build phase (the parent route's build is what mounts
    // this widget). Writing to a Riverpod notifier that AppShell is
    // currently watching trips the "modified provider while the
    // widget tree was building" assertion. A microtask runs after
    // the build phase completes for the current synchronous tick
    // but BEFORE the next frame's render — fast enough that the
    // new chrome paints in the same visible frame as the new page,
    // no 1-frame stale-chrome flicker.
    unawaited(Future.microtask(_publishChrome));
  }

  @override
  void didUpdateWidget(EdgeScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only republish when something the chrome cares about actually
    // changed. Avoids gratuitous notifier writes on every parent
    // rebuild.
    if (!identical(widget.actions, oldWidget.actions) ||
        widget.showBack != oldWidget.showBack ||
        widget.backFallbackRoute != oldWidget.backFallbackRoute ||
        !identical(widget.topOverlay, oldWidget.topOverlay)) {
      // Same reason as initState — defer past the current build
      // phase so we don't trip the Riverpod build-write guard.
      unawaited(Future.microtask(_publishChrome));
    }
  }

  @override
  void dispose() {
    // Pop our entry off the chrome stack so the previous route's
    // chrome (still on the stack under us) becomes visible again.
    // Safe to call synchronously here — the notifier's mutation
    // schedules AppShell's rebuild for the NEXT frame, after this
    // dispose has completed.
    _notifier?.pop(_chromeKey);
    _notifier = null;
    super.dispose();
  }

  void _publishChrome() {
    if (!mounted) return;
    _notifier?.push(
      _chromeKey,
      RouteChrome(
        showBack: widget.showBack,
        backFallbackRoute: widget.backFallbackRoute,
        actions: widget.actions,
        topOverlay: widget.topOverlay,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // System UI icons: dark icons over light scaffold, light over dark.
    // Per-screen AnnotatedRegion so each screen gets the right contrast
    // even if it's themed against the opposite scheme.
    final overlay = isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: const Color(0x00000000),
            systemNavigationBarColor: const Color(0x00000000),
            systemNavigationBarContrastEnforced: false,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: const Color(0x00000000),
            systemNavigationBarColor: const Color(0x00000000),
            systemNavigationBarContrastEnforced: false,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlay,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        extendBody: true,
        resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
        drawer: widget.drawer,
        // Body is just the page content now. Chrome (back, actions,
        // topOverlay) is painted by AppShell over the route, so we
        // don't render any Positioned widgets here.
        body: SafeArea(
          bottom: false,
          child: widget.body,
        ),
        floatingActionButton: widget.floatingActionButton,
        bottomSheet: widget.bottomSheet,
      ),
    );
  }
}
