/// Pure decision table for the AppShell back / swipe gesture.
///
/// Extracted from `AppShell.build` so the logic that decides
/// "pop / close overlay / go home / confirm exit" is unit-testable
/// WITHOUT standing up the full signed-in shell harness. This is the
/// regression net for the recurring nav bug class:
///   • "back / swipe exits the app from a non-home screen"
///   • "back goes to a screen I never visited"
/// Both stemmed from deciding the gesture off `matchedLocation` (a
/// shell-relative, unreliable signal). The shell now feeds this function
/// the SHELL navigator's real `canPop()` instead. See docs/NAV_MIGRATION.md.
library;

/// What a back gesture should do, given the shell's state.
enum ShellBackAction {
  /// Let the OS pop the shell navigator normally — a real drill-in
  /// (a route reached via `push`, or a child route under `/`).
  systemPop,

  /// Close the omnibox suggestion overlay first (don't touch the route).
  closeOverlay,

  /// Kid-mode locked surface — back is a deliberate no-op (the staff exit
  /// is a separate gesture; the router redirect owns the lock).
  kidModeNoop,

  /// Nothing to pop and NOT at a home root → route HOME. A top-level route
  /// reached via `go` replaced the shell stack, leaving nothing to pop;
  /// going home beats silently exiting the app.
  goHome,

  /// At a home root (`/` or `/login`) with nothing to pop → the user is
  /// leaving the app. Confirm first.
  confirmExit,
}

/// Decide what a back gesture should do.
///
/// - [shellCanPop]: the shell navigator's real `canPop()` — the
///   authoritative "is there a route to pop" signal, NOT `matchedLocation`
///   (shell-relative + unreliable inside a ShellRoute builder). The shell
///   feeds this from `context.canPop()`, which go_router's delegate
///   resolves THROUGH the shell navigator's `canPop()` — so that IS the
///   correct value to pass. Caveat: at BUILD time the read is stale-by-one
///   (the ShellRoute builder runs before its child navigator processes a
///   just-pushed page), so the shell re-reads it at GESTURE time before
///   calling this — see app_shell.dart's `onPopInvokedWithResult`.
/// - [overlayOpen]: the omnibox suggestion overlay is mounted.
/// - [inKidMode]: a kid-mode locked surface is active.
/// - [atHomeRoot]: the current location is `/` or `/login`.
///
/// Order matters: the overlay always wins (it forces the PopScope to
/// intercept), then a real pop, then the kid-mode no-op, then the
/// go-home fallback, and finally the exit confirmation.
ShellBackAction decideShellBack({
  required bool shellCanPop,
  required bool overlayOpen,
  required bool inKidMode,
  required bool atHomeRoot,
}) {
  if (overlayOpen) return ShellBackAction.closeOverlay;
  if (shellCanPop) return ShellBackAction.systemPop;
  if (inKidMode) return ShellBackAction.kidModeNoop;
  if (!atHomeRoot) return ShellBackAction.goHome;
  return ShellBackAction.confirmExit;
}

/// Whether `PopScope.canPop` should be `true` — i.e. let the OS pop the
/// shell navigator with no interception. Only when there's genuinely a
/// route to pop AND no overlay to close first; everything else is
/// intercepted so a back gesture can never accidentally exit the app.
///
/// Invariant: when this returns `true`, [decideShellBack] returns
/// [ShellBackAction.systemPop] for the same inputs.
bool shellShouldAllowSystemPop({
  required bool shellCanPop,
  required bool overlayOpen,
}) =>
    shellCanPop && !overlayOpen;
