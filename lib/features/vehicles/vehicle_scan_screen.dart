import 'dart:async';

import 'package:differentworld/features/vehicles/vehicle_deep_link.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Backup path for the OS deep link.
///
/// Most checkouts happen via the camera-app → universal-link path
/// (the QR encodes `differentworld://v/<id>/checkout`, the OS opens
/// the app at the right route). This screen exists for the case
/// where the OS hands the URL to the wrong handler (a browser, a
/// password manager, etc.) — the user can open Different World →
/// vehicles → "Scan" and get to the same place.
///
/// Behavior: opens the rear camera, decodes the FIRST QR that maps
/// to a known [VehicleDeepLink], pops back, and pushes the
/// corresponding inspection route. If the QR doesn't decode to a
/// vehicle link, an inline banner shows so the user can adjust
/// without leaving the scanner.
class VehicleScanScreen extends StatefulWidget {
  const VehicleScanScreen({super.key});

  @override
  State<VehicleScanScreen> createState() => _VehicleScanScreenState();
}

class _VehicleScanScreenState extends State<VehicleScanScreen> {
  late final MobileScannerController _controller;

  /// True between the moment we recognized a valid QR and the moment
  /// the pop+push completes. Prevents double-fires when the scanner
  /// re-detects the same code on the next frame.
  bool _handled = false;
  String? _hint;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      final link = VehicleDeepLink.tryParse(uri);
      if (link == null) {
        if (mounted) {
          setState(() => _hint = "That's not a Different World vehicle code.");
        }
        continue;
      }
      _handled = true;
      unawaited(HapticFeedback.mediumImpact());
      // Pop the scanner first, then push so the inspection screen
      // lands on top of the vehicles list (not the scanner).
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      unawaited(router.push(link.routePath));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EdgeScaffold(
      backFallbackRoute: '/vehicles',
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Aiming overlay — square cutout in the center so the user
          // knows where to point.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hint != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _hint!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Point at the QR code on the dashboard',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
