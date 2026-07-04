import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:differentworld/shared/widgets/camera_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// In-app camera that lets the user snap multiple photos in one
/// session without re-launching the camera each time. Returns the
/// captured XFiles via Navigator.pop.
///
/// Why custom instead of `image_picker`: the system camera intent
/// returns a single image per launch. Burst-style logging ("take five
/// quick shots of a child's painting") requires the camera to stay
/// open between shutter presses. This screen is that camera.
///
/// Future: this is the precursor to the face-aligned auto-snap camera
/// (CLAUDE.md "Face-aligned auto-snap camera (planned)"). When that
/// lands, the shutter button picks up an alignment guide and an auto-
/// snap trigger; the multi-shot logic stays the same.
class MultiShotCamera extends StatefulWidget {
  const MultiShotCamera({super.key});

  /// Open the camera as a fullscreen dialog. Returns the list of
  /// captured `XFile`s, or null if the user cancelled. Empty list is
  /// also possible (opened, snapped nothing, hit Done).
  static Future<List<XFile>?> open(BuildContext context) {
    return Navigator.of(context).push<List<XFile>>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const MultiShotCamera(),
      ),
    );
  }

  @override
  State<MultiShotCamera> createState() => _MultiShotCameraState();
}

class _MultiShotCameraState extends State<MultiShotCamera>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;
  final List<XFile> _captured = [];
  bool _busy = false;
  String? _error;
  List<CameraDescription> _cameras = const [];
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _bootCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The platform tears down the camera when the app backgrounds.
    // Re-init on resume so the preview comes back.
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      unawaited(c.dispose());
    } else if (state == AppLifecycleState.resumed) {
      _initFuture = _bootCamera();
      if (mounted) setState(() {});
    }
  }

  Future<void> _bootCamera() async {
    try {
      final cameras = await availableCameras();
      _cameras = cameras;
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _error = 'No camera available on this device.');
        }
        return;
      }
      // Prefer the back camera on first boot.
      final back = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _currentCameraIndex = back == -1 ? 0 : back;
      await _initControllerForCurrentCamera();
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = 'Camera unavailable: ${e.description}');
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = 'Could not start camera: $e');
    }
  }

  Future<void> _initControllerForCurrentCamera() async {
    final cam = _cameras[_currentCameraIndex];
    final controller = CameraController(
      cam,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    await _controller?.dispose();
    setState(() {
      _controller = controller;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2 || _busy) return;
    setState(() => _busy = true);
    try {
      _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
      await _initControllerForCurrentCamera();
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = 'Could not flip: ${e.description}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _snap() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    if (c.value.isTakingPicture) return;
    setState(() => _busy = true);
    unawaited(HapticFeedback.lightImpact());
    try {
      final x = await c.takePicture();
      if (!mounted) return;
      setState(() {
        _captured.add(x);
      });
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = 'Capture failed: ${e.description}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _removeAt(int index) {
    if (index < 0 || index >= _captured.length) return;
    // Best-effort cleanup of the temp file; ignore failures.
    unawaited(_deleteFile(_captured[index].path));
    setState(() => _captured.removeAt(index));
  }

  void _done() {
    Navigator.of(context).pop<List<XFile>>(_captured);
  }

  void _cancel() {
    // Drop temp files so we don't leak them — the picker normally
    // hands them to image_picker_lifecycle for cleanup, but we own
    // them ourselves on this path.
    for (final x in _captured) {
      unawaited(_deleteFile(x.path));
    }
    Navigator.of(context).pop();
  }

  Future<void> _deleteFile(String path) async {
    try {
      await File(path).delete();
    } on Exception {
      /* ignore */
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          leading: IconButton(
            tooltip: 'Cancel',
            icon: const Icon(Icons.close),
            onPressed: _cancel,
          ),
          actions: [
            if (_cameras.length > 1)
              IconButton(
                tooltip: 'Flip camera',
                icon: const Icon(Icons.cameraswitch_outlined),
                onPressed: _busy ? null : _flipCamera,
              ),
            TextButton(
              onPressed: _captured.isEmpty ? _cancel : _done,
              child: Text(
                _captured.isEmpty ? 'Cancel' : 'Done · ${_captured.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _error != null ? _errorView() : _cameraView(),
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraView() {
    final c = _controller;
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done ||
            c == null ||
            !c.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white70),
          );
        }
        return Stack(
          fit: StackFit.expand,
          children: [
            // Preview — fits the screen letterboxing if the aspect ratios
            // don't match. Camera previews on Pixel 6 default to ~4:3.
            Center(
              child: AspectRatio(
                aspectRatio: c.value.aspectRatio,
                child: CameraPreview(c),
              ),
            ),
            // Bottom controls: thumb strip + shutter button.
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_captured.isNotEmpty)
                        _ThumbStrip(
                          captured: _captured,
                          onRemove: _removeAt,
                        ),
                      const SizedBox(height: 16),
                      CamShutterButton(busy: _busy, onTap: _snap),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ThumbStrip extends StatelessWidget {
  const _ThumbStrip({required this.captured, required this.onRemove});

  final List<XFile> captured;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: captured.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _Thumb(
          file: captured[i],
          onRemove: () => onRemove(i),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(file.path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.white24,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.7),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
