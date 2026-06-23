import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/trip_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// The field-trip MAP — the HERO of a trip block's run-sheet bento. An
/// OpenStreetMap raster tile showing two pins: the DESTINATION (where the
/// group is headed) and the group's live "we are here" pin, with two actions
/// below — "Pin our spot" (drops the live GPS pin) and "Get directions"
/// (opens the device's native maps app).
///
/// Reads the trip's coordinates live from [tripLogisticsForBlockProvider]
/// (the `destination_lat/lng` + `pinned_lat/lng` columns slice 1 added). On
/// first build, if the destination has an ADDRESS but no coordinates yet, it
/// fires a one-shot geocode ([TripLocationActions.resolveDestinationCoords])
/// so the destination pin populates from the typed address — the result
/// arrives through the same watch and the map recenters on it.
///
/// Offline note: OSM tiles are fetched over the network, so OFFLINE the map
/// shows blank / gray tiles (a themed background fills behind them). That's
/// acceptable for v1 — tile caching is a later enhancement. GPS itself works
/// offline (the fix is from the location chip, not the network), so "Pin our
/// spot" still drops the live pin with no connection.
///
/// Theme: every marker / button / overlay colour comes from the
/// [ColorScheme]. The only "raw" surface is the OSM tile imagery itself —
/// fetched bitmaps, not Dart colour literals — so nothing here trips the
/// theme-adherence guard and no allowlist entry is needed.
class TripMapTile extends ConsumerStatefulWidget {
  const TripMapTile({
    required this.block,
    this.destinationName,
    super.key,
  });

  /// The field-trip block. Carries `id` (→ the logistics row) and the kind.
  final ScheduleBlock block;

  /// The destination's display NAME, shown as the map caption (e.g.
  /// "Lincoln Park Zoo"). Optional — when null, no caption name line shows.
  final String? destinationName;

  @override
  ConsumerState<TripMapTile> createState() => _TripMapTileState();
}

class _TripMapTileState extends ConsumerState<TripMapTile> {
  /// Recenters the camera when the destination geocode resolves or the group
  /// pin drops. `MapController()` is a factory → directly constructible in v7.
  final MapController _mapController = MapController();

  /// True while awaiting a GPS fix from "Pin our spot" — drives the inline
  /// spinner + disables the button so a double-tap can't fire two fixes.
  bool _pinning = false;

  /// The geocode-on-load is a ONE-SHOT: fire it at most once per mount, even
  /// across rebuilds, so a slow/failed geocode isn't retried on every frame.
  bool _geocodeFired = false;

  /// The map isn't ready to receive `move(...)` until the first frame mounts
  /// it. Until then we let `initialCenter` do the centering; after, we drive
  /// recenters through the controller. Flipped on the first build that has a
  /// usable center.
  bool _mapReady = false;

  /// The last center we drove the camera to — so we only `move(...)` when the
  /// resolved coordinates actually CHANGE (the destination geocode landing,
  /// or a fresh group pin), not on every unrelated rebuild.
  LatLng? _lastCentered;

  /// A gentle zoomed-out default when we have no coordinate at all yet — the
  /// continental US, so the empty map reads as "a map" rather than mid-ocean.
  static const LatLng _fallbackCenter = LatLng(39.8283, -98.5795);
  static const double _fallbackZoom = 3.5;
  static const double _placedZoom = 14;

  String get _blockId => widget.block.id;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Drop the group's live "we are here" pin from the device GPS. Optimistic:
  /// the write lands in Drift and the watch repaints the pin. A null fix
  /// (permission denied / location off / timeout) surfaces a non-blocking
  /// snackbar and leaves the map unchanged. NO coordinates are logged.
  Future<void> _pinOurSpot() async {
    if (_pinning) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _pinning = true);

    final actions = ref.read(tripLocationActionsProvider);
    // Read the fix directly so we know whether it succeeded (the action's
    // write is a no-op on a null fix); we use it both to recenter and to
    // decide whether to show the "couldn't get a location" snackbar.
    final fix = await ref.read(tripLocationServiceProvider).currentPosition();
    if (!mounted) return;

    if (fix == null) {
      setState(() => _pinning = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't get a location — check location permission.",
          ),
        ),
      );
      return;
    }

    // We have a fix → persist it through the actions API (same Drift write),
    // then recenter the camera on the new pin.
    await actions.pinGroupLocation(_blockId);
    if (!mounted) return;
    setState(() => _pinning = false);
    final at = LatLng(fix.lat, fix.lng);
    _lastCentered = at;
    if (_mapReady) _mapController.move(at, _placedZoom);
  }

  /// Open the device's native maps app with directions to the destination.
  /// Prefers the resolved coordinates ("lat,lng"); falls back to the
  /// URL-encoded address. Caller guarantees at least one is present (the
  /// button is hidden otherwise).
  Future<void> _getDirections({
    required double? destLat,
    required double? destLng,
    required String address,
  }) async {
    unawaited(HapticFeedback.selectionClick());
    final String destParam;
    if (destLat != null && destLng != null) {
      destParam = '$destLat,$destLng';
    } else {
      destParam = address;
    }
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent(destParam)}',
    );
    // Fire-and-forget on the platform; we don't block the UI on the launch.
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }

  /// Fire the destination geocode exactly once, after this frame, when the
  /// logistics has an address but no destination coordinates yet. Post-frame +
  /// mounted-guarded so it never runs during build or after dispose.
  void _maybeGeocode(TripLogistic logistics) {
    if (_geocodeFired) return;
    final hasCoords =
        logistics.destinationLat != null && logistics.destinationLng != null;
    final address = logistics.destinationAddress?.trim() ?? '';
    if (hasCoords || address.isEmpty) return;
    _geocodeFired = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref
            .read(tripLocationActionsProvider)
            .resolveDestinationCoords(_blockId, address),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final logistics = ref.watch(tripLogisticsForBlockProvider(_blockId)).value;

    // Resolved coordinates (null until set / geocoded).
    final destLat = logistics?.destinationLat;
    final destLng = logistics?.destinationLng;
    final pinLat = logistics?.pinnedLat;
    final pinLng = logistics?.pinnedLng;
    final address = logistics?.destinationAddress?.trim() ?? '';

    final destPoint = (destLat != null && destLng != null)
        ? LatLng(destLat, destLng)
        : null;
    final groupPoint = (pinLat != null && pinLng != null)
        ? LatLng(pinLat, pinLng)
        : null;

    // Fire the one-shot geocode if the destination has an address but no
    // coordinates yet (so the destination pin can populate from the address).
    if (logistics != null) _maybeGeocode(logistics);

    // Camera center precedence: the group pin if set, else the destination,
    // else the gentle zoomed-out default.
    final center = groupPoint ?? destPoint ?? _fallbackCenter;
    final zoom = (groupPoint != null || destPoint != null)
        ? _placedZoom
        : _fallbackZoom;

    // Recenter when the resolved center CHANGES (geocode landed / pin dropped)
    // — not on every rebuild. Post-frame so we never move during layout.
    if (groupPoint != null || destPoint != null) {
      if (_lastCentered == null ||
          _lastCentered!.latitude != center.latitude ||
          _lastCentered!.longitude != center.longitude) {
        _lastCentered = center;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_mapReady) return;
          _mapController.move(center, zoom);
        });
      }
    }

    final hasAnyDestination = destPoint != null || address.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 170,
            width: double.infinity,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                    // The blank/offline tile background follows the theme
                    // (the package default is a hardcoded light gray that
                    // looks broken in dark mode).
                    backgroundColor: scheme.surfaceContainerHighest,
                    // A static overview map: no panning/zooming gestures —
                    // taps belong to the tile, not the map.
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                    onMapReady: () {
                      if (!mounted) return;
                      setState(() => _mapReady = true);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.jardine.differentworld',
                      maxZoom: 19,
                    ),
                    if (destPoint != null || groupPoint != null)
                      MarkerLayer(
                        markers: [
                          if (destPoint != null)
                            Marker(
                              point: destPoint,
                              width: 44,
                              height: 44,
                              alignment: Alignment.topCenter,
                              child: _DestinationMarker(color: scheme.error),
                            ),
                          if (groupPoint != null)
                            Marker(
                              point: groupPoint,
                              width: 28,
                              height: 28,
                              child: _GroupMarker(
                                fill: scheme.primary,
                                ring: scheme.onPrimary,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                // "you are here" — only when the live pin is placed.
                if (groupPoint != null)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _MapChip(
                      label: 'you are here',
                      icon: Icons.my_location,
                      background: scheme.primary,
                      foreground: scheme.onPrimary,
                    ),
                  ),
                // The empty-map hint — only when NEITHER pin exists.
                if (destPoint == null && groupPoint == null)
                  Positioned.fill(
                    child: _EmptyMapHint(scheme: scheme),
                  ),
              ],
            ),
          ),
        ),
        // Caption: the destination name (when known) + its address.
        if ((widget.destinationName?.trim().isNotEmpty ?? false) ||
            address.isNotEmpty) ...[
          const SizedBox(height: 10),
          if (widget.destinationName?.trim().isNotEmpty ?? false)
            Text(
              widget.destinationName!.trim(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if (address.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              address,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
        const SizedBox(height: 12),
        // The two actions.
        Row(
          children: [
            Expanded(
              child: _MapActionButton(
                icon: Icons.my_location,
                label: 'Pin our spot',
                busy: _pinning,
                filled: true,
                onPressed: _pinOurSpot,
              ),
            ),
            if (hasAnyDestination) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _MapActionButton(
                  icon: Icons.directions_outlined,
                  label: 'Get directions',
                  busy: false,
                  filled: false,
                  onPressed: () => _getDirections(
                    destLat: destLat,
                    destLng: destLng,
                    address: address,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The DESTINATION marker — a filled map-pin glyph in a strong tone
/// ([ColorScheme.error]). `alignment: topCenter` on the Marker puts the pin's
/// tip on the exact point.
class _DestinationMarker extends StatelessWidget {
  const _DestinationMarker({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Destination',
      child: Icon(
        Icons.location_on,
        color: color,
        size: 40,
        // A soft shadow so the pin reads over busy map imagery.
        shadows: const [Shadow(blurRadius: 4, offset: Offset(0, 1))],
      ),
    );
  }
}

/// The GROUP "we are here" marker — a filled dot ([ColorScheme.primary]) with
/// a contrasting ring, centered on the live GPS point.
class _GroupMarker extends StatelessWidget {
  const _GroupMarker({required this.fill, required this.ring});

  final Color fill;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'You are here',
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: ring, width: 3),
            boxShadow: const [BoxShadow(blurRadius: 4, offset: Offset(0, 1))],
          ),
        ),
      ),
    );
  }
}

/// A small pill drawn over the map (the "you are here" label). Icon + label so
/// it never relies on colour alone.
class _MapChip extends StatelessWidget {
  const _MapChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The empty-map overlay — a soft prompt to drop the first pin, shown when
/// neither the destination nor the group pin is placed. A scrim keeps it
/// legible over whatever tiles are behind it.
class _EmptyMapHint extends StatelessWidget {
  const _EmptyMapHint({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        // A gentle wash over the tiles so the centered prompt reads.
        color: scheme.surface.withValues(alpha: 0.55),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.location_searching,
                color: scheme.onSurfaceVariant,
                size: 26,
              ),
              const SizedBox(height: 8),
              Text(
                "Tap 'Pin our spot' to place the group",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the map's two action buttons — a filled primary ("Pin our spot")
/// or a tonal secondary ("Get directions"). [busy] swaps the leading icon for
/// a spinner and disables the tap (so a GPS await can't be re-fired). Both are
/// ≥ 48 dp tall.
class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.filled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final leading = busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 18);
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        leading,
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size.fromHeight(48)),
    );
    if (filled) {
      return FilledButton(
        onPressed: busy ? null : onPressed,
        style: style,
        child: child,
      );
    }
    return FilledButton.tonal(
      onPressed: busy ? null : onPressed,
      style: style,
      child: child,
    );
  }
}
