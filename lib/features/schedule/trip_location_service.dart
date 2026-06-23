import 'package:differentworld/core/db/drift_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

/// On-device location + geocoding for field trips. Two capabilities,
/// both graceful: every method returns `null` rather than throwing when
/// the device can't help (permission denied, location off, no network
/// for geocoding, or a timeout), so the caller never has to wrap a
/// try/catch and the UI never shows an error for a missing fix.
///
/// Privacy: NO coordinates or addresses are ever logged in release.
/// Diagnostic prints are gated on [kDebugMode] and deliberately log only
/// the FAILURE MODE (e.g. "permission denied"), never the lat/lng or the
/// address string.
class TripLocationService {
  const TripLocationService();

  /// The device's current position as `(lat, lng)`, or `null` if we
  /// can't get one. Checks the location service is on and permission is
  /// granted (requesting it if not yet decided); returns `null` on
  /// denied / disabled / timeout. GPS works offline — the fix comes from
  /// the location chip, not the network.
  Future<({double lat, double lng})?> currentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) debugPrint('TripLocation: location service disabled');
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) debugPrint('TripLocation: location permission denied');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (lat: position.latitude, lng: position.longitude);
    } on Object catch (e) {
      // Timeout, platform exception, etc. — never surface as an error;
      // the caller treats null as "no fix this time."
      if (kDebugMode) debugPrint('TripLocation: currentPosition failed ($e)');
      return null;
    }
  }

  /// Geocode a free-form address to `(lat, lng)` via the platform's
  /// on-device geocoder (Android Geocoder / iOS CLGeocoder — no API
  /// key). Returns the first match, or `null` on an empty address, no
  /// result, offline, or failure. May need network, so a null result is
  /// expected when the device is offline.
  Future<({double lat, double lng})?> geocodeAddress(String address) async {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;
    try {
      final results = await geo.locationFromAddress(trimmed);
      if (results.isEmpty) return null;
      final first = results.first;
      return (lat: first.latitude, lng: first.longitude);
    } on Object catch (e) {
      // NEVER log the address (PII-ish — it can pinpoint a family). Only
      // the failure mode.
      if (kDebugMode) debugPrint('TripLocation: geocodeAddress failed ($e)');
      return null;
    }
  }
}

/// Provider-exposed [TripLocationService]. Const + stateless, so a plain
/// [Provider] is enough.
final tripLocationServiceProvider = Provider<TripLocationService>(
  (ref) => const TripLocationService(),
);

/// Optimistic field-trip location writes. Reads a fix / geocode via
/// [TripLocationService], then commits to local Drift through the trips
/// DAO — PowerSync syncs the coordinates to other staff + the family map
/// later. Both methods no-op silently when the device can't produce a
/// coordinate (null fix / failed geocode), matching the offline-first,
/// no-error-state contract.
class TripLocationActions {
  TripLocationActions(this._ref);
  final Ref _ref;

  /// Drop the group's live "we are here" pin for [blockId] from the
  /// device GPS. No-ops if there's no fix (denied / disabled / timeout).
  Future<void> pinGroupLocation(String blockId) async {
    final fix = await _ref.read(tripLocationServiceProvider).currentPosition();
    if (fix == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.tripsDao.setGroupPin(
      blockId,
      fix.lat,
      fix.lng,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Resolve [address] to coordinates and store them as the destination
  /// pin for [blockId]. No-ops if the address can't be geocoded (empty /
  /// no result / offline).
  Future<void> resolveDestinationCoords(String blockId, String address) async {
    final coords =
        await _ref.read(tripLocationServiceProvider).geocodeAddress(address);
    if (coords == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.tripsDao.setDestinationCoords(blockId, coords.lat, coords.lng);
  }
}

final tripLocationActionsProvider = Provider<TripLocationActions>(
  TripLocationActions.new,
);
