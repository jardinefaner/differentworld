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
///   WidgetsBinding.instance.addPostFrameCallback((_) {
///     ref.read(kidModeProvider.notifier).enter();
///   });
/// }
///
/// @override
/// void dispose() {
///   // Caller is responsible for exiting on the way out — kid-mode
///   // does NOT auto-exit on pop, because a kid tapping back is the
///   // failure mode we're locking down.
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
