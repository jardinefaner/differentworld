import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// OS-level **screen pinning** (Android lock-task) for the kid photo-turns
/// session — the layer ON TOP OF the in-app kid-lock (kidMode + the 5-tap
/// reclaim) that makes a kid handed the phone for their turn physically
/// unable to swipe out to another app.
///
/// Platform behaviour:
/// - **Android** — calls the native `com.jardine.differentworld/screen_pinning`
///   MethodChannel (`MainActivity.kt`). `pin()` enters lock-task; `unpin()`
///   leaves it. We are a NORMAL app (not device-owner), so the first `pin()`
///   shows the OS "Pin this app?" confirmation — that's expected, not a bug.
/// - **iOS** — there is NO programmatic Guided Access API for a normal app.
///   `pin()` / `unpin()` are no-ops; the SESSION screen instead shows a
///   one-time hint (see [needsManualLockHint]) telling staff to triple-click
///   the side button to start Guided Access themselves.
/// - **web / desktop** — no screen-pinning concept; all methods are no-ops.
///
/// Robustness: every channel call is wrapped so a device without lock-task
/// support (or an OS that refuses) can NEVER crash the turn flow — a failed
/// `pin()` just means the session runs with the in-app kid-lock alone. No PII
/// is ever logged (these calls carry none, and the debug logs are
/// `kDebugMode`-gated regardless).
class ScreenPinning {
  const ScreenPinning();

  static const MethodChannel _channel = MethodChannel(
    'com.jardine.differentworld/screen_pinning',
  );

  /// True only on native Android — the one platform with a programmatic
  /// lock-task API we drive from Dart. Guards `kIsWeb` first so touching
  /// `Platform` (from `dart:io`, which throws on web) is safe.
  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  /// True on iOS, where no programmatic screen-lock API exists for a normal
  /// app — the SESSION screen shows a one-time "use Guided Access" hint
  /// instead of pinning. False everywhere else (Android pins automatically;
  /// web/desktop have no concept of it).
  bool get needsManualLockHint => !kIsWeb && Platform.isIOS;

  /// Enter screen-pinning. On Android this triggers the OS confirm dialog the
  /// FIRST time (expected). No-op on every other platform. Never throws — a
  /// failure (unsupported device, user-declined, channel missing) is swallowed
  /// so the caller's session proceeds with the in-app kid-lock as the
  /// fallback.
  Future<void> pin() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('startLockTask');
    } on MissingPluginException catch (e) {
      // No native handler registered (e.g. an old engine / a platform that
      // doesn't wire MainActivity) — degrade silently.
      _log('pin: no native handler', e);
    } on PlatformException catch (e) {
      _log('pin: platform refused', e);
    } on Object catch (e) {
      _log('pin: unexpected', e);
    }
  }

  /// Leave screen-pinning. Idempotent — safe to call even when never pinned
  /// (the native side swallows "not pinned"). No-op off Android. Never throws,
  /// so a dispose path can always call it unconditionally.
  Future<void> unpin() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stopLockTask');
    } on MissingPluginException catch (e) {
      _log('unpin: no native handler', e);
    } on PlatformException catch (e) {
      _log('unpin: platform refused', e);
    } on Object catch (e) {
      _log('unpin: unexpected', e);
    }
  }

  /// Whether lock-task is currently active (Android only). False off Android,
  /// and false on any failure — callers use it as a best-effort signal, never
  /// a guarantee.
  Future<bool> isActive() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isLockTaskActive') ?? false;
    } on MissingPluginException catch (e) {
      _log('isActive: no native handler', e);
      return false;
    } on PlatformException catch (e) {
      _log('isActive: platform refused', e);
      return false;
    } on Object catch (e) {
      _log('isActive: unexpected', e);
      return false;
    }
  }

  /// Debug-only, PII-free logging. The screen-pinning channel carries no
  /// child data, but we gate on `kDebugMode` to match the project's logging
  /// rule (no logs in release builds).
  void _log(String where, Object error) {
    if (kDebugMode) {
      debugPrint('[screen-pinning] $where: $error');
    }
  }
}

/// The screen-pinning service. A `const` singleton — it holds no state, only
/// the platform-gated channel calls.
final Provider<ScreenPinning> screenPinningProvider = Provider<ScreenPinning>(
  (ref) => const ScreenPinning(),
);
