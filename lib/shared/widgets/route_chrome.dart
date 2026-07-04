import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the persistent top chrome (rendered by AppShell) should
/// display for the currently-mounted route. Set by `EdgeScaffold`
/// (in `lib/shared/widgets/edge_scaffold.dart`, which every route is
/// built on top of) in initState / didUpdateWidget, and read by
/// AppShell to paint the chrome layer over the page transition.
///
/// The provider is a STACK underneath — each `push(key, ...)` adds a
/// new entry; each `pop(key)` removes one; the active chrome is
/// always the top of the stack. That's the load-bearing trick that
/// lets back-pop restore the previous route's chrome automatically —
/// when EdgeScaffold's dispose fires, it pops its own entry, and the
/// previous route's entry (still on the stack from its earlier push)
/// becomes the visible chrome again.
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

class _StackEntry {
  const _StackEntry(this.key, this.chrome);
  final Object key;
  final RouteChrome chrome;
}

/// Notifier that holds the active route's chrome AS A STACK. Each
/// `EdgeScaffold` push'es its own entry on mount and pop's it on
/// dispose. The exposed `state` is always the top of the stack (or
/// default when empty). Watchers (AppShell) read `state` and re-
/// paint as the top changes.
///
/// Why a stack and not a single slot:
/// - Route A mounts → push A → state = A. AppShell paints A's chrome.
/// - Route B pushed onto A → push B → stack [A, B], state = B. Paint B.
/// - Route B popped → pop B → stack `[A]`, state = A. Paint A.
///
/// Without the stack, B's chrome would linger on the screen after
/// popping back to A because A's EdgeScaffold doesn't re-mount and
/// has no reason to republish its own chrome.
class RouteChromeNotifier extends Notifier<RouteChrome> {
  /// Mutable stack — last entry is the active chrome.
  final List<_StackEntry> _stack = <_StackEntry>[];

  @override
  RouteChrome build() => const RouteChrome();

  /// Add or update the entry for [key]. If [key] is already in the
  /// stack (typical for didUpdateWidget on the active route), update
  /// in place — don't reorder.
  void push(Object key, RouteChrome chrome) {
    final i = _stack.indexWhere((e) => e.key == key);
    if (i >= 0) {
      _stack[i] = _StackEntry(key, chrome);
    } else {
      _stack.add(_StackEntry(key, chrome));
    }
    state = _stack.isEmpty ? const RouteChrome() : _stack.last.chrome;
  }

  /// Remove the entry for [key]. State falls back to whatever entry
  /// is now at the top (or default when the stack is empty).
  void pop(Object key) {
    _stack.removeWhere((e) => e.key == key);
    state = _stack.isEmpty ? const RouteChrome() : _stack.last.chrome;
  }

  /// Drop everything — used when the AppShell wants a clean slate
  /// (e.g. sign-out flushing residual chrome from staff screens).
  void clear() {
    _stack.clear();
    state = const RouteChrome();
  }
}

// Riverpod 3 doesn't yet have a stable public-typed name for
// NotifierProvider so we have to write the type out explicitly.
final NotifierProvider<RouteChromeNotifier, RouteChrome> routeChromeProvider =
    NotifierProvider<RouteChromeNotifier, RouteChrome>(
      RouteChromeNotifier.new,
    );
