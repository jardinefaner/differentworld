import 'dart:async';

import 'package:camera/camera.dart';
import 'package:differentworld/features/vehicles/vehicle_photo_shots.dart';
import 'package:differentworld/shared/widgets/camera_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One captured photo, tied to the shot it satisfies.
class CapturedShot {
  CapturedShot({
    required this.key,
    required this.label,
    required this.file,
    required this.bytes,
  });

  final String key;
  final String label;
  final XFile file;
  final Uint8List bytes;
}

/// A guided, stay-open camera that walks a named shot list (docs/VISION.md —
/// vehicle guided-photo capture). The prompt names exactly what to shoot; a
/// tap captures it and AUTO-ADVANCES to the next un-captured shot without
/// leaving the camera. A filmstrip of slots shows progress; tap a slot to
/// retake. Done (enabled once every `required` shot is captured) pops the
/// captures back to the caller, which uploads them.
///
/// Returns `List<CapturedShot>` via `Navigator.pop` (ordered by shot);
/// the close (X) pops `null` (cancelled).
class GuidedCaptureScreen extends StatefulWidget {
  const GuidedCaptureScreen({
    required this.shots,
    required this.title,
    super.key,
  });

  final List<VehiclePhotoShot> shots;
  final String title;

  @override
  State<GuidedCaptureScreen> createState() => _GuidedCaptureScreenState();
}

class _GuidedCaptureScreenState extends State<GuidedCaptureScreen>
    with WidgetsBindingObserver, CameraSessionMixin {
  bool _shooting = false;

  /// Captures keyed by shot key (null = not yet taken).
  final Map<String, CapturedShot> _captured = {};
  int _current = 0;

  List<VehiclePhotoShot> get _shots => widget.shots;
  VehiclePhotoShot get _shot => _shots[_current];
  int get _capturedCount => _captured.length;
  bool get _allRequiredDone => _shots
      .where((s) => s.required)
      .every((s) => _captured.containsKey(s.key));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(initCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      unawaited(initCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    disposeCamera();
    super.dispose();
  }

  /// After a capture, jump to the next un-captured shot (search forward,
  /// then wrap); if everything's captured, stay put.
  void _advance() {
    for (var step = 1; step <= _shots.length; step++) {
      final i = (_current + step) % _shots.length;
      if (!_captured.containsKey(_shots[i].key)) {
        _current = i;
        return;
      }
    }
  }

  Future<void> _shoot() async {
    final c = cameraController;
    if (c == null ||
        !c.value.isInitialized ||
        c.value.isTakingPicture ||
        _shooting) {
      return;
    }
    setState(() => _shooting = true);
    try {
      final file = await c.takePicture();
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final shot = _shot;
      setState(() {
        _captured[shot.key] = CapturedShot(
          key: shot.key,
          label: shot.label,
          file: file,
          bytes: bytes,
        );
        _advance();
      });
      unawaited(HapticFeedback.mediumImpact());
    } on Object catch (_) {
      // A dropped frame isn't fatal — the shot just isn't recorded.
    } finally {
      if (mounted) setState(() => _shooting = false);
    }
  }

  void _done() {
    final ordered = <CapturedShot>[
      for (final s in _shots) ?_captured[s.key],
    ];
    Navigator.of(context).pop(ordered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (camStatus) {
        CamStatus.ready when cameraController?.value.isInitialized ?? false =>
          _cameraView(context),
        CamStatus.denied => CamMessage(
          icon: Icons.no_photography_outlined,
          title: 'Camera access needed',
          message: 'Allow the camera to take the required vehicle photos.',
          actionLabel: 'Try again',
          onAction: () {
            setState(() => camStatus = CamStatus.initializing);
            unawaited(initCamera());
          },
        ),
        CamStatus.unavailable => const CamMessage(
          icon: Icons.videocam_off_outlined,
          title: 'No camera here',
          message: 'This device has no camera available.',
        ),
        _ => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      },
    );
  }

  Widget _cameraView(BuildContext context) {
    final c = cameraController!;
    return Stack(
      fit: StackFit.expand,
      children: [
        _preview(c),
        Positioned(top: 0, left: 0, right: 0, child: _topBar()),
        Positioned(bottom: 0, left: 0, right: 0, child: _bottomBar()),
      ],
    );
  }

  Widget _preview(CameraController c) {
    final size = c.value.previewSize;
    if (size == null) return const ColoredBox(color: Colors.black);
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(c),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final total = _shots.length;
    final captured = _captured.containsKey(_shot.key);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      '$_capturedCount of $total captured',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ),
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    if (captured)
                      const Padding(
                        padding: EdgeInsets.only(right: 8, top: 2),
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.greenAccent,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _shot.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (_shot.hint.isNotEmpty)
                            Text(
                              _shot.hint,
                              style: const TextStyle(color: Colors.white70),
                            ),
                        ],
                      ),
                    ),
                    if (_shot.required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Required',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _slotStrip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Row(
                children: [
                  const SizedBox(width: 72),
                  Expanded(
                    child: Center(
                      child: CamShutterButton(busy: _shooting, onTap: _shoot),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: TextButton(
                      onPressed: _allRequiredDone ? _done : null,
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: _allRequiredDone
                              ? Colors.white
                              : Colors.white38,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotStrip() {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _shots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _shots[i];
          final cap = _captured[s.key];
          final isCurrent = i == _current;
          return GestureDetector(
            onTap: () => setState(() => _current = i),
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent ? Colors.white : Colors.white24,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: cap != null
                  ? Image.memory(
                      cap.bytes,
                      width: 56,
                      height: 72,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    )
                  : Center(
                      child: Icon(
                        s.required
                            ? Icons.error_outline
                            : Icons.radio_button_unchecked,
                        color: s.required ? Colors.amberAccent : Colors.white38,
                        size: 20,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
