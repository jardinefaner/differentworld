import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:differentworld/core/invites/invite_code.dart';
import 'package:differentworld/features/vehicles/vehicle_deep_link.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds a pending invite code captured from an inbound deep link
/// before the app could process it (e.g. cold-launch via a QR scan
/// while not yet signed in). Cleared once consumed.
class PendingInviteCode extends Notifier<String?> {
  @override
  String? build() => null;

  // Named `set` (not a setter) so callers stay imperative-explicit
  // alongside `clear()` — `pending.set('ABC123')` reads better than
  // `pending.value = 'ABC123'`.
  // ignore: use_setters_to_change_properties
  void set(String? code) => state = code;

  void clear() => state = null;
}

final pendingInviteCodeProvider = NotifierProvider<PendingInviteCode, String?>(
  PendingInviteCode.new,
);

/// Wires the OS deep-link plumbing — `differentworld://invite/<code>` on
/// mobile, `https://differentworld.app/invite/<code>` on Android (App
/// Link fallback; not yet auto-verified). Stashes the extracted code
/// into [pendingInviteCodeProvider] so screens can react.
///
/// Read-only side effect: the redeem call itself is made by whichever
/// screen sees the pending code and decides what to do (gate on auth
/// state, on already-having-a-space, etc.). Keeping the listener as
/// "stash and notify" makes the routing decisions one-source-of-truth
/// instead of scattered across listener + router.
class DeepLinkService {
  DeepLinkService(this._ref);

  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialChecked = false;

  Future<void> start() async {
    // Cold-launch: the URI that opened the app, if any.
    if (!_initialChecked) {
      _initialChecked = true;
      try {
        final initial = await _appLinks.getInitialLink();
        if (initial != null) _ingest(initial);
      } on PlatformException catch (e, st) {
        // Debug-only: a deeplink error message can echo back the URI
        // and the URI carries the invite code — sensitive in
        // production logs.
        if (kDebugMode) {
          debugPrint('[deeplink] getInitialLink failed: $e\n$st');
        }
      }
    }

    // Warm-app re-entry: every subsequent URI delivered while running.
    _sub ??= _appLinks.uriLinkStream.listen(
      _ingest,
      onError: (Object e, StackTrace st) {
        // Same redaction rationale as getInitialLink.
        if (kDebugMode) {
          debugPrint('[deeplink] uriLinkStream error: $e\n$st');
        }
      },
    );
  }

  void _ingest(Uri uri) {
    // Inbound URIs are sensitive — invite codes grant guardian access
    // and vehicle ids are PII-adjacent. Never log payloads in
    // production; debug-only and gated.
    if (kDebugMode) {
      debugPrint('[deeplink] received: $uri');
    }

    // Try invite first (most common deep link by volume).
    final code = InviteCode.extractFromUri(uri);
    if (code != null) {
      _ref.read(pendingInviteCodeProvider.notifier).set(code);
      return;
    }

    // Vehicle checkout / checkin (QR on dashboard / key fob).
    final vehicle = VehicleDeepLink.tryParse(uri);
    if (vehicle != null) {
      _ref.read(pendingVehicleDeepLinkProvider.notifier).set(vehicle);
      return;
    }

    if (kDebugMode) {
      debugPrint('[deeplink] URI not recognized; ignoring');
    }
  }

  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
  }
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final svc = DeepLinkService(ref);
  ref.onDispose(svc.dispose);
  return svc;
});

/// Eagerly starts the listener at app boot. Call `ref.read(...)` once
/// from `lib/main.dart` (or wherever the ProviderScope mounts) so the
/// service initializes before the first frame.
final deepLinkBootProvider = FutureProvider<void>((ref) async {
  final svc = ref.read(deepLinkServiceProvider);
  await svc.start();
});
