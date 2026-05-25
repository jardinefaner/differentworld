import 'package:differentworld/features/vehicles/vehicles_providers.dart'
    show VehicleLogKind;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A parsed vehicle deep link — the vehicle's id + which way the
/// driver intends to log (checkout / checkin).
///
/// Sources:
/// - Custom scheme: `differentworld://v/<vehicleId>/checkout`
/// - HTTPS: `https://differentworld.app/v/<vehicleId>/checkout`
///   (HTTPS works after `.well-known/assetlinks.json` +
///   `apple-app-site-association` are hosted; until then, custom scheme
///   carries the load — see `AndroidManifest.xml` / `Info.plist`.)
class VehicleDeepLink {
  const VehicleDeepLink({required this.vehicleId, required this.kind});

  final String vehicleId;

  /// One of [VehicleLogKind.checkout] / [VehicleLogKind.checkin].
  final String kind;

  /// Returns null when [uri] is not a vehicle deep link this app
  /// understands. Tolerates leading slashes and the two recognized
  /// host shapes (`v` for the short form, `differentworld.app` for the
  /// HTTPS form).
  ///
  /// Path shape on both: `/<vehicleId>/<kind>`.
  static VehicleDeepLink? tryParse(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments;

    final customScheme = scheme == 'differentworld' && host == 'v';
    final httpsScheme = (scheme == 'https' || scheme == 'http') &&
        host == 'differentworld.app' &&
        segments.isNotEmpty &&
        segments.first == 'v';

    if (!customScheme && !httpsScheme) return null;

    final path = customScheme ? segments : segments.skip(1).toList();
    if (path.length < 2) return null;
    final id = path[0];
    final kind = path[1].toLowerCase();
    if (id.isEmpty) return null;
    if (kind != VehicleLogKind.checkout && kind != VehicleLogKind.checkin) {
      return null;
    }
    return VehicleDeepLink(vehicleId: id, kind: kind);
  }

  /// Build the custom-scheme URI for [vehicleId] + [kind]. Used by the
  /// QR generator so the printed sticker carries the same URL the
  /// listener parses.
  static Uri customSchemeUri({
    required String vehicleId,
    required String kind,
  }) =>
      Uri.parse('differentworld://v/$vehicleId/$kind');

  /// Build the HTTPS form for [vehicleId] + [kind]. Used by the QR
  /// generator AFTER the `.well-known/` files are hosted on
  /// differentworld.app; until then prefer [customSchemeUri].
  static Uri httpsUri({
    required String vehicleId,
    required String kind,
  }) =>
      Uri.parse('https://differentworld.app/v/$vehicleId/$kind');

  /// Path inside the app router. Pair with `context.push` from the
  /// signed-in shell when a pending link lands.
  String get routePath => '/settings/vehicles/$vehicleId/$kind';
}

/// Holds a pending vehicle deep link captured at app boot or during a
/// warm session, before whichever surface that handles the routing
/// has had a chance to react. Same shape as `pendingInviteCodeProvider`
/// — the listener stashes, a router-side listener consumes.
class PendingVehicleDeepLinkNotifier extends Notifier<VehicleDeepLink?> {
  @override
  VehicleDeepLink? build() => null;

  // Named `set` (matches the invite listener's API) so callers
  // stay imperative-explicit alongside `clear()`.
  // ignore: use_setters_to_change_properties
  void set(VehicleDeepLink? link) => state = link;

  void clear() => state = null;
}

final pendingVehicleDeepLinkProvider =
    NotifierProvider<PendingVehicleDeepLinkNotifier, VehicleDeepLink?>(
  PendingVehicleDeepLinkNotifier.new,
);
