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

  /// Safety net: releases the controller even if a host forgets to call
  /// [disposeCamera] in its own dispose (a leaked controller keeps the OS
  /// camera open). Idempotent — hosts that already call it are unaffected.
  @override
  void dispose() {
    disposeCamera();
    super.dispose();
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

  /// The flash-cycle + lens-flip button pair every camera top bar carries.
  /// A min-size inner Row, so it inlines into the host bar's Row unchanged.
  Widget camFlashFlipButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CamCapButton(
          icon: camFlash == FlashMode.off
              ? Icons.flash_off
              : camFlash == FlashMode.auto
              ? Icons.flash_auto
              : Icons.flash_on,
          active: camFlash != FlashMode.off,
          tooltip: 'Flash',
          onTap: () => unawaited(cycleFlash()),
        ),
        const SizedBox(width: 8),
        CamCapButton(
          icon: Icons.cameraswitch_outlined,
          tooltip: 'Flip camera',
          onTap: () => unawaited(switchCamera()),
        ),
      ],
    );
  }

  /// The not-ready body for a camera surface: denied (with a retry that
  /// re-runs [initCamera]), unavailable, or the initializing spinner.
  /// [deniedMessage] names what the camera is FOR on this screen.
  Widget camStatusFallback({required String deniedMessage}) {
    switch (camStatus) {
      case CamStatus.denied:
        return CamMessage(
          icon: Icons.no_photography_outlined,
          title: 'Camera access needed',
          message: deniedMessage,
          actionLabel: 'Try again',
          onAction: () {
            setState(() => camStatus = CamStatus.initializing);
            unawaited(initCamera());
          },
        );
      case CamStatus.unavailable:
        return const CamMessage(
          icon: Icons.videocam_off_outlined,
          title: 'No camera here',
          message: 'This device has no camera available.',
        );
      case CamStatus.initializing:
      case CamStatus.ready:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
    }
  }
}

/// Cover-fit camera preview: fills the surface, cropping overflow. The
/// inner SizedBox swaps the (landscape) sensor preview dimensions so the
/// portrait feed scales correctly inside the FittedBox.
class CamCoverPreview extends StatelessWidget {
  const CamCoverPreview(this.controller, {super.key});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return const ColoredBox(color: Colors.black);
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

/// The black-to-transparent gradient scrim behind a camera control bar,
/// including the SafeArea for the matching screen edge. The host supplies
/// its own inner padding (bar layouts differ per screen).
class CamScrim extends StatelessWidget {
  const CamScrim.top({required this.child, super.key}) : _top = true;
  const CamScrim.bottom({required this.child, super.key}) : _top = false;

  final Widget child;
  final bool _top;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: _top ? Alignment.topCenter : Alignment.bottomCenter,
          end: _top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: const [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(top: _top, bottom: !_top, child: child),
    );
  }
}

/// The bottom control row of a camera surface: two fixed-width side slots
/// flanking the centered shutter, with the standard 24/10/24/20 padding.
/// Fixed-width slots (not Expanded) keep the shutter optically centered
/// whatever the side content is.
class CamShutterRow extends StatelessWidget {
  const CamShutterRow({
    required this.busy,
    required this.onShoot,
    this.left,
    this.right,
    this.slotWidth = 64,
    super.key,
  });

  final bool busy;
  final VoidCallback onShoot;
  final Widget? left;
  final Widget? right;
  final double slotWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
      child: Row(
        children: [
          SizedBox(width: slotWidth, child: left),
          Expanded(
            child: Center(
              child: CamShutterButton(busy: busy, onTap: onShoot),
            ),
          ),
          SizedBox(width: slotWidth, child: right),
        ],
      ),
    );
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
