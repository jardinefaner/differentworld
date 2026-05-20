import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the persistent top chrome (rendered by AppShell) should
/// display for the currently-mounted route. Set by `EdgeScaffold`
/// (in `lib/shared/widgets/edge_scaffold.dart`, which every route is
/// built on top of) in initState / didUpdateWidget, and read by
/// AppShell to paint the chrome layer over the page transition.
///
/// The point of this indirection: when the user pushes a new route,
/// the page-content slides/fades but the back button and action pill
/// remain visually anchored. That's the LLM-style "persistent chrome,
/// transitioning conversation" feel. Without this, the back button
/// + actions slide with each new screen as part of its scaffold,
/// which makes the app read as a stack of pages instead of a fluid
/// surface.
class RouteChrome {
  const RouteChrome({
    this.showBack = false,
    this.backFallbackRoute = '/',
    this.actions = const <Widget>[],
    this.topOverlay,
  });

  /// Render the floating back button on the left. False on the home
  /// page; true on every drill-in.
  final bool showBack;

  /// Where back navigates to when the navigator stack is empty (cold
  /// launch directly into a deep-linked route).
  final String backFallbackRoute;

  /// Per-route action pill content (already filtered + wrapped — the
  /// caller is responsible for any "search" icon, mode-specific
  /// chips, etc.).
  final List<Widget> actions;

  /// When non-null, replaces BOTH the left chrome (back) AND the
  /// right chrome (actions) with a single full-width overlay. Used
  /// by Today's "inline search bar" transformation — the chrome
  /// morphs into a search input in place.
  final Widget? topOverlay;
}

/// Notifier that holds the active route's chrome. Routes call
/// `.set(...)` from inside `EdgeScaffold`'s initState /
/// didUpdateWidget; AppShell watches and paints the chrome at the
/// top of every frame.
class RouteChromeNotifier extends Notifier<RouteChrome> {
  @override
  RouteChrome build() => const RouteChrome();

  /// Replace the active chrome wholesale. Diffing happens at the
  /// caller (EdgeScaffold only writes when its incoming props change),
  /// not here.
  // ignore: use_setters_to_change_properties
  void set(RouteChrome chrome) {
    state = chrome;
  }

  /// Reset to defaults — used when the active route is one that
  /// doesn't use EdgeScaffold (raw modal, fullscreen photo viewer)
  /// and the previous route's chrome would otherwise linger.
  void reset() {
    state = const RouteChrome();
  }
}

// Riverpod 3 doesn't yet have a stable public-typed name for
// NotifierProvider so we have to write the type out explicitly.
final NotifierProvider<RouteChromeNotifier, RouteChrome>
    routeChromeProvider =
    NotifierProvider<RouteChromeNotifier, RouteChrome>(
  RouteChromeNotifier.new,
);
