import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Shared session plumbing + chrome for the app's camera surfaces
/// (photography runner, vehicle guided capture, multi-shot camera).
///
/// Camera viewfinders are raw canvases (docs/THEME_ADHERENCE.md): black
/// preview, white controls, hardcoded colors are correct here — this file
/// is on the theme-guard allowlist.
///
/// This is also the staging ground for the planned face-aligned auto-snap
/// camera (CLAUDE.md): when that lands, it composes these same pieces.

/// Where the camera session is in its lifecycle.
enum CamStatus { initializing, ready, denied, unavailable }

/// The vetted open/close/flip/flash state machine for a stay-open camera.
///
/// Carries the hard-won lifecycle fixes in ONE place (they were previously
/// copy-pasted between screens):
/// - `initCamera` is re-entrancy-guarded and disposes a controller that
///   finishes initializing after the screen is gone.
/// - `disposeCamera` resets the in-flight guard too: backgrounding DURING
///   init (permission dialog up, controller still null) would otherwise
///   leave it true and make the resume-time `initCamera` early-return
///   forever — camera stuck on the spinner.
///
/// Screens keep their own `didChangeAppLifecycleState` (they differ — the
/// photography runner re-engages its kid lock there) and call
/// `disposeCamera()` / `initCamera()` from it.
mixin CameraSessionMixin<T extends StatefulWidget> on State<T> {
  CameraController? cameraController;
  CamStatus camStatus = CamStatus.initializing;
  bool _camInitInFlight = false;

  CameraLensDirection camLens = CameraLensDirection.back;
  FlashMode camFlash = FlashMode.off;

  /// Override to read capability ranges (zoom) off the freshly
  /// initialized controller, before it's published. Must not setState.
  Future<void> onCameraReady(CameraController controller) async {}

  Future<void> initCamera() async {
    if (_camInitInFlight || cameraController != null) return;
    _camInitInFlight = true;
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => camStatus = CamStatus.denied);
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => camStatus = CamStatus.unavailable);
        return;
      }
      final cam = cams.firstWhere(
        (c) => c.lensDirection == camLens,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await onCameraReady(controller);
      try {
        await controller.setFlashMode(camFlash);
      } on Object catch (_) {
        // Some lenses (front) don't support flash — ignore.
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        cameraController = controller;
        camStatus = CamStatus.ready;
      });
    } on Object catch (_) {
      if (mounted) setState(() => camStatus = CamStatus.unavailable);
    } finally {
      _camInitInFlight = false;
    }
  }

  void disposeCamera() {
    final c = cameraController;
    cameraController = null;
    _camInitInFlight = false;
    unawaited(c?.dispose());
  }

  Future<void> switchCamera() async {
    camLens = camLens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    disposeCamera();
    setState(() => camStatus = CamStatus.initializing);
    await initCamera();
  }

  Future<void> cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(camFlash) + 1) % order.length];
    setState(() => camFlash = next);
    final c = cameraController;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setFlashMode(next);
    } on Object catch (_) {
      // Lens doesn't support it — the icon still reflects intent.
    }
  }
}

/// Full-screen message on the black camera surface (permission denied,
/// no camera) with an optional retry action.
class CamMessage extends StatelessWidget {
  const CamMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A round translucent camera-capability button (flash, flip).
class CamCapButton extends StatelessWidget {
  const CamCapButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: active
                ? Colors.amberAccent.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.4),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: active ? Colors.black : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

/// The 76dp ring shutter. Dims while a capture is in flight.
class CamShutterButton extends StatelessWidget {
  const CamShutterButton({required this.busy, required this.onTap, super.key});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Take photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: busy ? Colors.white54 : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
