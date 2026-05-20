import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kid-mode: when ON, the AppShell hides the omnibox composer and
/// the drawer affordance, and gates back-navigation so a kid handed
/// the device on a survey / journal surface can't drift into staff-
/// facing parts of the app.
///
/// Exit is staff-only — surfaces that enter kid mode are
/// responsible for rendering an exit affordance (a hidden multi-tap
/// area, a PIN dialog, etc.) and calling `.exit()` when the
/// gesture/PIN check passes. A reusable `KidModeExitOverlay` is
/// future work (CLAUDE.md persona "Ava" section).
///
/// Surfaces opt INTO kid mode via:
///
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   // Defer through a microtask — initState runs DURING the
///   // parent's build phase, and AppShell watches kidModeProvider,
///   // so a sync write trips Riverpod's "modified during build"
///   // assertion. Microtask fires after the build phase finishes
///   // but BEFORE the next frame's render, so kid mode is active
///   // by the time the kid surface paints. Don't use
///   // `addPostFrameCallback` — that fires AFTER the next frame,
///   // introducing a 1-frame window where staff chrome is still
///   // visible on the kid surface.
///   unawaited(Future.microtask(() {
///     if (!mounted) return;
///     ref.read(kidModeProvider.notifier).enter();
///   }));
/// }
///
/// @override
/// void dispose() {
///   // Drop the lock when the screen pops. For surfaces a kid
///   // might launch (kid-journal, future activity check-ins), use
///   // a staff-only exit instead — see CLAUDE.md persona "Ava".
///   ref.read(kidModeProvider.notifier).exit();
///   super.dispose();
/// }
/// ```
///
/// Exit MUST go through `KidMode.exit` (via a staff gesture / PIN);
/// route-pop alone doesn't unlock — that's the entire point of the
/// lockdown.
class KidMode extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() {
    state = true;
  }

  /// Staff-initiated exit. Called by surfaces (or a future
  /// `KidModeExitOverlay`) after the user completes the unlock
  /// gesture / PIN check.
  void exit() {
    state = false;
  }
}

final NotifierProvider<KidMode, bool> kidModeProvider =
    NotifierProvider<KidMode, bool>(KidMode.new);
