import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences is a direct dep in pubspec.yaml; the analyzer
// sometimes warns spuriously across pub workspace boundaries.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

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
/// **Persistence**: the locked state is mirrored to SharedPreferences
/// so backgrounding + reopening the app (or an Android Activity
/// resurrection) doesn't silently drop the lock. The notifier reads
/// the persisted value on `build` and writes through on every
/// `enter` / `exit`. Without this, a kid who backgrounded the app
/// mid-survey could reopen to a kid-mode-OFF AppShell with the
/// survey route still on top — full staff chrome visible, omnibox
/// composer reachable.
///
/// Surfaces opt INTO kid mode via:
///
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   unawaited(Future.microtask(() {
///     if (!mounted) return;
///     ref.read(kidModeProvider.notifier).enter();
///   }));
/// }
///
/// @override
/// void dispose() {
///   ref.read(kidModeProvider.notifier).exit();
///   super.dispose();
/// }
/// ```
///
/// Exit MUST go through `KidMode.exit` (via a staff gesture / PIN);
/// route-pop alone doesn't unlock — that's the entire point of the
/// lockdown.
class KidMode extends Notifier<bool> {
  static const _kPrefsKey = 'kid_mode.locked';

  @override
  bool build() {
    // Restore the persisted value asynchronously. We start in
    // `false` (the conservative default — if a kid surface needs
    // the lock, it will call `.enter()` on mount) and flip true if
    // the persisted value says so. This handles the
    // background-and-reopen case: if the app was force-quit while
    // locked, the next launch starts locked too, and the surface
    // that originally launched kid mode is responsible for staying
    // mounted (or re-engaging on resume — see survey_take_screen).
    unawaited(_loadInitial());
    return false;
  }

  Future<void> _loadInitial() async {
    // Web doesn't persist kid mode. A laptop / desktop browser is
    // never going to be "handed to a kid" — the use case is mobile-
    // only. Persisting on web means a survey-take session from a
    // dev's testing pins kid-mode on across all subsequent visits,
    // hiding the staff chrome and looking like the app is broken.
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getBool(_kPrefsKey) ?? false;
      if (persisted && !state) {
        state = true;
      }
    } on Object catch (e, st) {
      if (kDebugMode) {
        debugPrint('[kid-mode] persistence load failed: $e\n$st');
      }
    }
  }

  void enter() {
    state = true;
    unawaited(_persist(true));
  }

  /// Staff-initiated exit. Called by surfaces (or a future
  /// `KidModeExitOverlay`) after the user completes the unlock
  /// gesture / PIN check.
  void exit() {
    state = false;
    unawaited(_persist(false));
  }

  Future<void> _persist(bool value) async {
    // Skip persistence on web — see `_loadInitial` for rationale.
    // Also actively clear any stale value so a user upgrading from
    // an older build that DID persist on web doesn't stay locked.
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kPrefsKey);
      } on Object catch (_) {
        // best-effort
      }
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefsKey, value);
    } on Object catch (e, st) {
      // Persistence is best-effort — if we can't write, the lock
      // still works for the current session. Don't crash; the
      // failure mode is "kid backgrounds + reopens after a crash =
      // staff chrome visible" which is no worse than the pre-
      // persistence behavior.
      if (kDebugMode) {
        debugPrint('[kid-mode] persistence write failed: $e\n$st');
      }
    }
  }
}

final NotifierProvider<KidMode, bool> kidModeProvider =
    NotifierProvider<KidMode, bool>(KidMode.new);

/// URL the kid is pinned to during a kid-mode lockdown.
///
/// Wave 106: on Flutter web, `PopScope.canPop: false` only blocks
/// Flutter Navigator pops — the browser back button calls
/// `window.history.back()` directly, which bypasses PopScope and
/// pops the route. That route's dispose calls
/// `kidModeProvider.notifier.exit()`, but for the brief window the
/// kid lands on a staff-facing surface with the chrome already
/// stripped. The router redirect reads THIS provider and bounces
/// any navigation away from `lockedRoute` back to it; combined
/// with PopScope on native, kid-mode is locked across both
/// platforms.
///
/// Surfaces opt in via:
///
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   unawaited(Future.microtask(() {
///     if (!mounted) return;
///     ref.read(kidModeProvider.notifier).enter();
///     ref.read(kidModeLockedRouteProvider.notifier).state =
///         '/surveys/${widget.templateId}/take/${widget.subjectId}';
///   }));
/// }
///
/// @override
/// void dispose() {
///   ref.read(kidModeProvider.notifier).exit();
///   ref.read(kidModeLockedRouteProvider.notifier).state = null;
///   super.dispose();
/// }
/// ```
///
/// Why a separate provider (not a field on KidMode): keeps the
/// boolean-shaped `kidModeProvider` API stable so the dozen-plus
/// existing call sites that watch it as `bool` don't need to
/// change.
class KidModeLockedRoute extends Notifier<String?> {
  @override
  String? build() => null;

  /// Pin the router to `route` (or `null` to clear the pin). Named
  /// instead of using `state =` directly so call sites read with
  /// intent — `pin(url)` to lock, `pin(null)` to release.
  // ignore: use_setters_to_change_properties
  void pin(String? route) => state = route;
}

final NotifierProvider<KidModeLockedRoute, String?>
    kidModeLockedRouteProvider =
    NotifierProvider<KidModeLockedRoute, String?>(KidModeLockedRoute.new);
