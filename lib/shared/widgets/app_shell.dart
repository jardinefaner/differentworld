import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/dev_flags/dev_flags.dart';
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/family/guardian_drawer.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/live_session/cast_chrome_button.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/features/omnibox/bottom_omnibox_bar.dart';
import 'package:differentworld/features/roles/preview_banner.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/speak/speak_immersive.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/debug_viewer_toggle.dart';
import 'package:differentworld/shared/widgets/desktop_nav_rail.dart';
import 'package:differentworld/shared/widgets/floating_actions.dart';
import 'package:differentworld/shared/widgets/floating_back.dart';
import 'package:differentworld/shared/widgets/floating_hamburger.dart';
import 'package:differentworld/shared/widgets/live_block_strip.dart';
import 'package:differentworld/shared/widgets/main_drawer.dart';
import 'package:differentworld/shared/widgets/route_chrome.dart';
import 'package:differentworld/shared/widgets/shell_back_action.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Persistent app shell — drawer + top chrome + bottom omnibox bar.
///
/// **Wave-back-to-route (2026-06-20).** The omnibox search surface used
/// to be an in-shell OVERLAY mounted in this shell's Stack (Wave 25): the
/// editable composer lived in the bottom BAR and a translucent suggestion
/// panel opened above it on focus. That overlay caused two problems —
/// (a) a left-swipe fell through this shell's PopScope to the app-exit
/// confirm ("swipe exits the app"), and (b) the frosted glass over the
/// page was hard to read. It's now a real go_router route again
/// (`/search` → `OmniboxSearchScreen`), and the KEY change that makes the
/// route work this time is that the input FIELD lives ON that page,
/// autofocused — so there is no cross-route focus handoff to tear down the
/// IME (the original "keyboard appears then disappears" bug that drove the
/// Wave-25 overlay). Result: all the composer / overlay / voice state that
/// used to live here is gone; the bottom bar is now a presentational
/// tap-target that pushes `/search`.
///
/// What still lives here (the things that genuinely persist across page
/// transitions):
/// - Drawer ownership (one MainDrawer for the whole app)
/// - Top chrome stack (hamburger / back / actions pills)
/// - Bottom omnibox bar (a tap-target → `/search`, anchored as routes
///   change, LLM-chat style). The voice mic + composer field moved ONTO
///   the search page.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Re-entrancy guard for the "Close Different World?" confirm dialog. A
  /// second back gesture in the window before the dialog route mounts must
  /// not stack a second dialog (the documented "gesture → async dialog
  /// re-entrancy" class). Set true while the dialog is in flight.
  bool _confirmExitOpen = false;

  /// Push the `/search` route — the bottom bar's tap target and the
  /// Cmd/Ctrl-K / Cmd/Ctrl-/ shortcuts both call this. The page's own
  /// autofocused field raises the keyboard on mount.
  void _openSearch() {
    // uri.path, NOT matchedLocation — inside the ShellRoute builder
    // matchedLocation is shell-relative and unreliable. Don't stack a
    // second /search if we're already on it.
    if (GoRouterState.of(context).uri.path == '/search') return;
    unawaited(context.push('/search'));
  }

  /// Paint the active route's chrome (back button / hamburger +
  /// actions OR a full-width top overlay) as floating Positioned
  /// widgets at the top of the AppShell's body Stack.
  List<Widget> _buildTopChrome(
    RouteChrome chrome,
    double topInset, {
    required bool showDrawer,
  }) {
    // Stable keys on every emitted Positioned so the Stack's
    // reconciliation stays predictable when sibling Stack children
    // (the omnibox overlay, the bar) come and go. Without keys,
    // Flutter would shuffle Element-to-Widget matches on every
    // build and the bar's TextField would rebuild, dropping its
    // input connection → keyboard close.
    if (chrome.topOverlay != null) {
      return [
        Positioned(
          key: const ValueKey('shell-chrome-overlay'),
          top: topInset + 8,
          left: 8,
          right: 8,
          child: chrome.topOverlay!,
        ),
      ];
    }
    final widgets = <Widget>[];
    final leftChrome = <Widget>[];
    if (showDrawer) {
      leftChrome.add(const FloatingHamburger());
    }
    if (chrome.showBack) {
      if (leftChrome.isNotEmpty) {
        leftChrome.add(const SizedBox(width: 8));
      }
      leftChrome.add(
        FloatingBack(
          fallbackRoute: chrome.backFallbackRoute,
        ),
      );
    }
    if (leftChrome.isNotEmpty) {
      widgets.add(
        Positioned(
          key: const ValueKey('shell-chrome-left'),
          top: topInset + 8,
          left: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: leftChrome,
          ),
        ),
      );
    }
    // Wave 168: dev-only viewer-kind toggle ALWAYS renders in the
    // action pill in debug builds, alongside any route-specific
    // actions. Lets the developer impersonate a Teacher / Substitute
    // / Specialist / Guardian etc. without signing out. Compiled
    // out of release builds via the `if (kDebugMode)` guard on the
    // widget side (the import itself stays; the toggle's build
    // returns SizedBox.shrink in release so it costs nothing).
    final actionsForPill = <Widget>[
      if (kDebugMode) const DebugViewerToggle(),
      // App-wide cast (docs/LIVE_SESSIONS.md): one tap to the screen from any
      // staff route — slice 1 opens the launcher. Auto-hidden in immersive /
      // kid-mode (the whole chrome is). Guardians don't cast.
      if (ref.read(viewerProvider).isDailyLogger) const CastChromeButton(),
      ...chrome.actions,
    ];
    if (actionsForPill.isNotEmpty) {
      widgets.add(
        Positioned(
          key: const ValueKey('shell-chrome-actions'),
          top: topInset + 8,
          right: 8,
          child: FloatingActions(children: actionsForPill),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final inKidMode = ref.watch(kidModeProvider);
    final chrome = ref.watch(routeChromeProvider);
    final topInset = MediaQuery.paddingOf(context).top;

    final viewer = ref.watch(viewerProvider);
    // Keep the guardian's children list warm for the whole session so the
    // GuardianDrawer (rebuilt on each open) doesn't re-fetch + flash empty.
    if (viewer is GuardianViewer) ref.watch(familyChildrenProvider);
    final showDrawer = viewer.isSignedIn && !inKidMode;
    // Wave 121: at desktop widths the hamburger drawer is replaced
    // by a persistent left-side nav rail. The rail only renders for
    // signed-in staff (guardians have no peer destinations to nav
    // between — they live on /, /messages, /children/*), and is
    // hidden in kid mode same as the drawer.
    final viewportWidth = MediaQuery.sizeOf(context).width;
    // Immersive present/cast surfaces own the WHOLE viewport on desktop too —
    // a fullscreen cast with the 240dp nav rail still docked left is the
    // "left menu on the projector" bug (2026-08-02). Read the immersive
    // signals here (before the rail decision); `isImmersive` below adds the
    // route-prefix half for the bar, which needs `location` from the router.
    final immersiveProviderOn =
        ref.watch(speakImmersiveProvider) || ref.watch(castImmersiveProvider);
    // The fullscreen activity routes hide chrome by route prefix; the rail
    // must honor that too. uri.path is the full active location — reliable,
    // unlike matchedLocation, which stays at the shell's own match
    // (verified on device: `/breaks` while uri.path is the real child).
    final immersiveRoute = GoRouterState.of(
      context,
    ).uri.path.startsWith('/activity/');
    final showDesktopRail =
        showDrawer &&
        viewer is! GuardianViewer &&
        !immersiveProviderOn &&
        !immersiveRoute &&
        viewportWidth >= Breakpoints.tablet;

    // ── Back / swipe model (Wave: reliable nav) ──────────────────────
    // The authoritative "is there a route to pop" signal is the SHELL
    // navigator's own canPop() — a fact about the real stack — NOT
    // `matchedLocation` (shell-relative + unreliable inside a ShellRoute
    // builder) and NOT `context.canPop()` (reflects the imputed match
    // list, which lies when a route was reached via `go`).
    //
    // The rule (decided in onPopInvokedWithResult below):
    //   • shell can pop             → let the system pop normally. (The
    //                                 `/search` route is an ordinary push,
    //                                 so back / left-swipe on it just pops —
    //                                 NOT the old "fall through to app-exit"
    //                                 path that bit the in-shell overlay.)
    //   • shell can't pop, not home → return HOME. A top-level route
    //                                 reached via `go` replaced the stack,
    //                                 so there's nothing to pop — going home
    //                                 beats silently exiting the app (the
    //                                 "back/swipe exits" bug).
    //   • shell can't pop, at home  → confirm app exit.
    //
    // AppShell depends on GoRouterState (the immersive-route read above),
    // so it rebuilds on every navigation — `shellCanPop` is recomputed each
    // route change and the captured closure values stay fresh.
    // `context.canPop()` resolves to the shell navigator's real
    // `canPop()` (go_router's delegate walks the ShellRouteMatch). NOTE it
    // is stale-by-ONE here: AppShell (the ShellRoute builder) builds BEFORE
    // its child navigator processes the just-pushed page, so right after a
    // push from a 1-deep stack this still reads the pre-push value. That's
    // why this build-time read is used only as a CONSERVATIVE gate, and the
    // back handler RE-READS canPop at gesture time (when the stack has
    // settled) to make the final decision. See docs/NAV_MIGRATION.md.
    final shellCanPop = context.canPop();
    // Immersive activity routes (games, This or That, pattern, role cards)
    // hide the omnibox bar + reclaim its bottom space — like kid mode but
    // WITHOUT the lock. They're full-screen surfaces; the bar both clutters
    // them and steals the ~76 dp their layouts need.
    final isImmersive = immersiveRoute || immersiveProviderOn;

    // PopScope.canPop=true → the system pops the shell navigator normally
    // (drill-ins reached via `push`, including `/search`); false → we
    // intercept below and decide (go home / confirm exit). The decision
    // table lives in shell_back_action.dart so it's unit-tested
    // independently of the shell.
    final canPop = shellShouldAllowSystemPop(shellCanPop: shellCanPop);

    // Keyboard shortcuts — desktop-/web-friendly verbs. Cmd-K opens
    // the omnibox (the universal "go anywhere" verb); Cmd-/ also opens
    // (a Discord / Slack convention). Both push the `/search` route whose
    // own field autofocuses. Esc is no longer bound — the route's own back
    // handles dismissal. Mobile users never hit these but they're free to
    // add — `CallbackShortcuts` only fires when a keyboard is present.
    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): _openSearch,
      const SingleActivator(LogicalKeyboardKey.keyK, control: true):
          _openSearch,
      const SingleActivator(LogicalKeyboardKey.slash, meta: true): _openSearch,
      const SingleActivator(LogicalKeyboardKey.slash, control: true):
          _openSearch,
    };

    return CallbackShortcuts(
      bindings: shortcuts,
      child: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          // We only get here when the build-time gate (canPop) was false, so
          // RE-READ canPop + location at GESTURE TIME — the navigator stack
          // has settled by now, unlike the stale-by-one build-time read.
          // This is what makes a first-level push (home → detail) pop back
          // to home properly instead of falling through to go-home. Same
          // decision table the unit test pins (shell_back_action.dart).
          final freshLocation = GoRouterState.of(context).uri.path;
          final action = decideShellBack(
            shellCanPop: context.canPop(),
            inKidMode: ref.read(kidModeProvider),
            atHomeRoot: freshLocation == '/' || freshLocation == '/login',
          );
          switch (action) {
            case ShellBackAction.kidModeNoop:
              // The router's kidModeLockedRouteProvider redirect owns the
              // lock; back is a deliberate no-op on a locked surface (the
              // staff exit is the 5-tap gesture).
              return;
            case ShellBackAction.systemPop:
              // Build-time gate read "can't pop" (stale-by-one right after a
              // push), but the settled stack CAN pop → pop via go_router so
              // the URL stays in sync with the navigator. (mounted is true
              // synchronously here, but guard for parity with the others.)
              if (!mounted) return;
              if (context.canPop()) context.pop();
              return;
            case ShellBackAction.goHome:
              // Nothing to pop AND not at a home root → a top-level route
              // whose shell stack was replaced via `go`. Return HOME instead
              // of letting the pop exit the app. The fix for "back/swipe
              // exits at some screens" + "back goes somewhere I never
              // visited" — home is always the predictable destination.
              if (!mounted) return;
              context.go('/');
              return;
            case ShellBackAction.confirmExit:
              break;
          }
          // confirmExit: at a home root with nothing to pop → the user is
          // leaving the app. Confirm. Re-entrancy guard: a second back in
          // the window before the dialog route mounts must not stack a
          // second dialog.
          if (!mounted || _confirmExitOpen) return;
          _confirmExitOpen = true;
          try {
            final shouldExit = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Close Different World?'),
                content: const Text(
                  'You can come back anytime — your work is saved.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Stay'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
            if (!mounted) return;
            if (shouldExit ?? false) {
              // `SystemNavigator.pop()` finishes the activity on Android
              // (returns to launcher) and is a no-op on iOS (Apple HIG
              // forbids programmatic exit). That's fine — iOS users
              // background via the home gesture.
              await SystemNavigator.pop();
            }
          } finally {
            _confirmExitOpen = false;
          }
        },
        child: Scaffold(
          // Wave 121: at desktop the persistent rail replaces the
          // hamburger drawer. Drawer slot stays wired below desktop so
          // phone / tablet keep their existing swipe-from-edge gesture
          // + hamburger pill.
          // Guardians get their own drawer (Today / each child / Messages /
          // Display) — the staff MainDrawer is full of capability-gated
          // destinations a parent can't use. Both reachable via the same
          // hamburger + swipe gesture.
          drawer: (showDrawer && !showDesktopRail)
              ? (viewer is GuardianViewer
                    ? const GuardianDrawer()
                    : const MainDrawer())
              : null,
          // `resizeToAvoidBottomInset: true` is load-bearing — it shrinks
          // the body so the keyboard occupies its own space below the
          // body. The omnibox bar lives at the bottom of that body, so
          // it sits flush above the keyboard with no extra math.
          resizeToAvoidBottomInset: true,
          body: showDesktopRail
              ? Row(
                  children: [
                    const SizedBox(width: 240, child: DesktopNavRail()),
                    Expanded(
                      child: _buildBodyStack(
                        inKidMode: inKidMode,
                        viewer: viewer,
                        topInset: topInset,
                        chrome: chrome,
                        showDrawer: false, // hamburger pill hidden at desktop
                        isImmersive: isImmersive,
                        context: context,
                      ),
                    ),
                  ],
                )
              : _buildBodyStack(
                  inKidMode: inKidMode,
                  viewer: viewer,
                  topInset: topInset,
                  chrome: chrome,
                  showDrawer: showDrawer,
                  isImmersive: isImmersive,
                  context: context,
                ),
        ),
      ),
    );
  }

  /// Wave 121: the body Stack is now used either standalone (phone /
  /// tablet — the existing rendering) or as the right column of a
  /// desktop layout (alongside [DesktopNavRail]). Extracting it as a
  /// method lets us call it in both shapes without duplicating the
  /// 100+ lines of stack contents.
  Widget _buildBodyStack({
    required bool inKidMode,
    required Viewer viewer,
    required double topInset,
    required RouteChrome chrome,
    required bool showDrawer,
    required bool isImmersive,
    required BuildContext context,
  }) {
    return Stack(
      // Every child is keyed so Flutter's reconciliation matches
      // them by key+type, not list position. Without keys, toggling a
      // conditional child (the live-block strip appearing, immersive
      // mode hiding the bar) shifts the rest of the children's
      // positions; Flutter then matches existing Elements to wrong
      // slots and an interactive child would rebuild unexpectedly. The
      // keys are cheap insurance and are the documented fix for the
      // "sibling-insert poisons an Element" class (CLAUDE.md gotcha).
      children: [
        // Route content. Edge-to-edge: the body fills the viewport
        // from top to bottom; the floating chrome pills + omnibox
        // bar overlay it as translucent glass elements. We only
        // reserve BOTTOM space (so the last scrolled item doesn't
        // sit forever behind the omnibox); the TOP is intentionally
        // un-padded so list content scrolls THROUGH the chrome
        // strip — Wave 52 reverted the prior "padded below the
        // chrome" layout-law because it produced a solid-coloured
        // strip at top that read as an opaque appbar even though
        // the pills themselves were already glass.
        //
        // Routes typically start with a ContentHeader; that header
        // is wide enough that the chrome pills (~48dp each, top
        // ~64dp area) only overlap a sliver of it, and the glass
        // blur keeps the underlying text readable.
        Padding(
          key: const ValueKey('shell-route-content'),
          padding: EdgeInsets.only(
            // No omnibox bar for guardians, in kid mode, or on immersive
            // activity routes → no bottom reservation; route content can
            // fill all the way to the gesture inset.
            bottom: (inKidMode || viewer is GuardianViewer || isImmersive)
                ? 0
                : ShellMetrics.bottomOmniboxHeight,
          ),
          // Wave 127: SelectionArea moved here from
          // MaterialApp.builder. Now sits inside the routed
          // Navigator's Overlay scope (provided by Scaffold's
          // ancestor Navigator), so the SelectableRegion's
          // upward Overlay lookup succeeds. Every `Text` inside
          // a route body becomes click-and-drag selectable; the
          // platform default copy/select-all toolbar shows on
          // selection. Excludes chrome / omnibox / drawer (they
          // sit outside this Padding in the Stack), which is
          // the right call — selecting "Today" out of a chrome
          // pill isn't what users want.
          child: SelectionArea(child: widget.child),
        ),
        // Persistent top chrome (hamburger + back + per-route
        // actions). Hidden in kid mode AND in immersive surfaces
        // (the cast cockpit/receiver, Speak, /activity games) — those
        // own the whole screen and carry their own header/exit, so the
        // floating pills only collided with their content (they buried
        // the cockpit's own title). This matches the omnibox bar's gate
        // below + the "auto-hidden in immersive" intent in the cast
        // button. The `/search` route is an ordinary page that renders
        // its own EdgeScaffold back pill via the chrome stack — no
        // special-casing here any more (the in-shell overlay used to
        // need a synthetic back-pill that closed it).
        if (!inKidMode && !isImmersive)
          ..._buildTopChrome(
            chrome,
            topInset,
            showDrawer: showDrawer,
          ),
        // The bottom omnibox bar (a tap-target → `/search`). Sits flush
        // above the home-indicator safe area. Hidden in kid mode so the
        // kid surface has no staff-facing affordance. Also hidden for
        // guardians — the omnibox catalog is staff-only (settings,
        // captures, tasks, observations, etc.) and the family lens has
        // its own navigation pattern via the Family Today header — and on
        // immersive /activity/* routes, which are full-screen surfaces.
        // ALSO hidden when the current route IS `/search`, so the search
        // page's own field is the single input (no redundant "tap to
        // search" pill floating over the page that already has search).
        //
        // Live-block strip — sits directly above the omnibox bar,
        // collapses to zero height when nothing is live. Same guards as
        // the bar: staff only, not kid mode, not immersive, not /search.
        // Role preview announces itself on EVERY route, not just where you
        // started it. A lens you can forget you are wearing is a trap: a
        // director who stops seeing Billing would conclude the app broke,
        // and every judgement they made from then on would be about a role
        // they are not. Carries a stable key like its siblings — this Stack
        // is the one that drops the omnibox's IME when children shuffle.
        if (!inKidMode && !isImmersive)
          const Positioned(
            key: ValueKey('shell-role-preview'),
            left: 0,
            right: 0,
            top: 0,
            child: PreviewBanner(),
          ),
        if (!inKidMode &&
            viewer is! GuardianViewer &&
            !isImmersive &&
            !_onSearchRoute(context))
          Positioned(
            key: const ValueKey('shell-live-strip'),
            left: 0,
            right: 0,
            bottom: ShellMetrics.bottomOmniboxHeight,
            child: LiveBlockStrip(
              liveBlock: ref.watch(liveBlockProvider),
            ),
          ),
        if (!inKidMode &&
            viewer is! GuardianViewer &&
            !isImmersive &&
            !_onSearchRoute(context))
          Positioned(
            key: const ValueKey('shell-omnibox-bar'),
            left: 0,
            right: 0,
            bottom: 0,
            child: BottomOmniboxBar(onTap: _openSearch),
          ),
        // DEV-ONLY: a floating flag to bookmark this screen for the next
        // Claude Code session (read via scripts/read_dev_flags.sh). Gated on
        // kDebugMode so it never ships; hidden in kid mode like the rest.
        if (kDebugMode && !inKidMode)
          const Positioned(
            key: ValueKey('shell-dev-flag'),
            right: 12,
            bottom: ShellMetrics.bottomOmniboxHeight + 12,
            child: DevFlagButton(),
          ),
      ],
    );
  }

  /// Whether the active route is the `/search` page. Read from
  /// `uri.path` (NOT matchedLocation, which is shell-relative inside the
  /// ShellRoute builder). The bar hides on `/search` so the page's own
  /// field is the only input.
  bool _onSearchRoute(BuildContext context) =>
      GoRouterState.of(context).uri.path == '/search';
}
