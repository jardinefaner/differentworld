import 'dart:async';

import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/shared/widgets/route_chrome.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';
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
    this.background,
    super.key,
  });

  final Widget body;

  /// Optional decorative layer painted BEHIND the body (a `Stack` fill,
  /// pointer-transparent) — e.g. a room's themed `RoomSkinBackground` decal.
  /// Kept generic (a `Widget`) so this shared scaffold stays feature-agnostic;
  /// the screen builds the themed background and passes it here. Null = none.
  final Widget? background;

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
    //
    // **Why deferred.** An older comment here claimed it was safe to
    // pop synchronously because "AppShell's rebuild is scheduled for
    // the next frame, after dispose completes." That was wrong:
    // during a route pop, the disposing widget's `dispose()` is
    // called DURING the widget tree's finalize phase, which is
    // itself a build-phase for the assertion's purposes. Writing
    // `state = …` synchronously here trips Riverpod's
    // "modify provider while widget tree was building" assertion,
    // and the assertion firing leaves the chrome stack in an
    // inconsistent state so subsequent routes show no chrome or bar.
    //
    // Defer the pop into a microtask — same pattern the push side
    // already uses. The microtask runs after the current sync tick
    // (so this dispose has fully finalized) but before the next
    // frame's render, so the chrome visually flips on the same frame
    // the new route paints.
    //
    // Capture the notifier handle locally so the microtask doesn't
    // touch `_notifier` after we've nulled it; the element is
    // deactivated by then and any field reads would crash anyway.
    final notifier = _notifier;
    _notifier = null;
    final key = _chromeKey;
    if (notifier != null) {
      unawaited(Future.microtask(() {
        try {
          notifier.pop(key);
        } on Object {
          // Notifier may already be disposed (e.g. the ProviderScope
          // tore down before the microtask ran — happens during test
          // teardown and on app-shutdown). Chrome stack cleanup is
          // best-effort housekeeping; if the provider's already gone,
          // there's nothing to clean.
        }
      }));
    }
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
    // The floating chrome (hamburger + back + actions) is painted by
    // AppShell over the body — EXCEPT in kid mode, where AppShell hides
    // it (app_shell.dart `if (!inKidMode)`). So we reserve its band only
    // when it's actually shown.
    final inKidMode = ref.watch(kidModeProvider);
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
        // True edge-to-edge (Wave 53). The body fills the entire
        // Scaffold area; the floating chrome pills (top) + omnibox bar
        // (bottom) are translucent glass overlays AppShell paints on top.
        //
        // The ONE thing this wrapper does is publish the top-chrome band
        // into the body's `MediaQuery.padding.top` ([_ChromeInsetBody]).
        // That makes the chrome a real system inset, so any `SafeArea`
        // or `ContentHeader` inside ANY body clears the pills
        // automatically — no per-screen `topChromeHeight` math to
        // remember (and forget). It does NOT wrap the body in a SafeArea:
        // that would paint a solid scaffold-coloured strip behind the
        // chrome (the old "appbar background color" complaint) and block
        // content from scrolling under the glass. Full-bleed bodies that
        // opt out of SafeArea (the camera) are unaffected.
        body: widget.background == null
            ? _ChromeInsetBody(
                reserve: inKidMode ? 0 : ShellMetrics.topChromeHeight,
                child: widget.body,
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(child: widget.background),
                  ),
                  _ChromeInsetBody(
                    reserve: inKidMode ? 0 : ShellMetrics.topChromeHeight,
                    child: widget.body,
                  ),
                ],
              ),
        floatingActionButton: widget.floatingActionButton,
        bottomSheet: widget.bottomSheet,
      ),
    );
  }
}

/// Publishes the floating top-chrome band into the body's
/// `MediaQuery.padding.top`, so a `SafeArea` / `ContentHeader` anywhere
/// in the body clears the pills with no per-screen math.
///
/// Built as a child of the Scaffold's `body`, so it reads the
/// MediaQuery the body actually sees (after Scaffold's own adjustments)
/// and layers the chrome reservation on top. [reserve] is 0 in kid mode
/// (AppShell hides the chrome there) — then this is a pass-through.
class _ChromeInsetBody extends StatelessWidget {
  const _ChromeInsetBody({required this.reserve, required this.child});

  final double reserve;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reserve == 0) return child;
    final mq = MediaQuery.of(context);
    final p = mq.padding;
    return MediaQuery(
      data: mq.copyWith(
        padding: EdgeInsets.only(
          left: p.left,
          top: p.top + reserve,
          right: p.right,
          bottom: p.bottom,
        ),
      ),
      child: child,
    );
  }
}
