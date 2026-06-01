import 'dart:async';

import 'package:camera/camera.dart';
import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/photography.dart';
import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// `/activity/photo?prompt=...` — the Photography activity, runnable live
/// (docs/ACTIVITY_RUNTIME.md §5). Opens straight to the camera; the
/// instruction rides in the overlay; shoot as many as you like; Done →
/// a full-screen gallery of everything captured. Kid-mode locked: full
/// screen, no chrome, staff 5-tap (+ PIN) to exit.
///
/// Prototype scope: photos are held in memory for this session — no
/// Storage upload, no persistence as entries yet (the binary-media path:
/// compress → Supabase Storage → row carries the path; offline queue —
/// is the next step, per CLAUDE.md). In-memory bytes keep it web-safe
/// (no dart:io) and let the live demo work today.
class PhotographyRunnerScreen extends ConsumerStatefulWidget {
  const PhotographyRunnerScreen({
    this.prompt = 'Capture what you see',
    super.key,
  });

  final String prompt;

  @override
  ConsumerState<PhotographyRunnerScreen> createState() =>
      _PhotographyRunnerScreenState();
}

enum _CamStatus { initializing, ready, denied, unavailable }

class _PhotographyRunnerScreenState
    extends ConsumerState<PhotographyRunnerScreen>
    with WidgetsBindingObserver {
  late final ActivityRun _run = ActivityRun(
    photographyActivity(prompt: widget.prompt),
  );

  CameraController? _controller;
  _CamStatus _cam = _CamStatus.initializing;
  bool _initInFlight = false;
  bool _shooting = false;

  /// Captured photo bytes for this session (newest last).
  final List<Uint8List> _photos = <Uint8List>[];

  // Kid-mode lockdown — notifiers cached in initState (ref is unsafe in
  // dispose); the screen drives its own lock via _staffUnlocked (it does
  // NOT ref.watch a provider it mutates in dispose).
  late final KidMode _kidMode;
  late final KidModeLockedRoute _lockedRoute;
  bool _staffUnlocked = false;
  int _staffTaps = 0;
  Timer? _staffTapReset;
  static const _staffTapTarget = 5;
  static const _staffTapWindow = Duration(seconds: 2);

  static const String _route = '/activity/photo';

  @override
  void initState() {
    super.initState();
    _kidMode = ref.read(kidModeProvider.notifier);
    _lockedRoute = ref.read(kidModeLockedRouteProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        _kidMode.enter();
        _lockedRoute.pin(_route);
      }),
    );
    unawaited(_initCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_staffUnlocked && mounted) {
      _kidMode.enter();
      _lockedRoute.pin(_route);
    }
    // The camera plugin requires releasing the controller when the app is
    // backgrounded, and re-acquiring on resume (only while still shooting).
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeCamera();
    } else if (state == AppLifecycleState.resumed &&
        _run.current.mode == ActivityMode.shoot) {
      unawaited(_initCamera());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _staffTapReset?.cancel();
    _kidMode.exit();
    _lockedRoute.pin(null);
    _disposeCamera();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (_initInFlight || _controller != null) return;
    _initInFlight = true;
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _cam = _CamStatus.denied);
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _cam = _CamStatus.unavailable);
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cam = _CamStatus.ready;
      });
    } on Object catch (_) {
      // No camera plugin (web/desktop/test) or init failure → degrade.
      if (mounted) setState(() => _cam = _CamStatus.unavailable);
    } finally {
      _initInFlight = false;
    }
  }

  void _disposeCamera() {
    final c = _controller;
    _controller = null;
    unawaited(c?.dispose());
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null ||
        !c.value.isInitialized ||
        c.value.isTakingPicture ||
        _shooting) {
      return;
    }
    setState(() => _shooting = true);
    try {
      final shot = await c.takePicture();
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() => _photos.add(bytes));
      unawaited(HapticFeedback.mediumImpact());
    } on Object catch (_) {
      // A single dropped frame isn't fatal — keep the camera live.
    } finally {
      if (mounted) setState(() => _shooting = false);
    }
  }

  void _finishShooting() {
    _disposeCamera();
    setState(() => _run.advance()); // → gallery
  }

  Future<void> _onStaffCornerTap() async {
    _staffTaps += 1;
    _staffTapReset?.cancel();
    if (_staffTaps >= _staffTapTarget) {
      _staffTaps = 0;
      final result = await showKidModeExitDialog(context, ref);
      if (!mounted) return;
      switch (result) {
        case KidModeExitResult.unlocked:
        case KidModeExitResult.noPinConfigured:
          setState(() => _staffUnlocked = true);
          _lockedRoute.pin(null);
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(content: Text('Unlocked. Press back to exit.')),
          );
        case KidModeExitResult.cancelled:
          break;
      }
      return;
    }
    _staffTapReset = Timer(_staffTapWindow, () {
      if (mounted) _staffTaps = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final blockPop = !_staffUnlocked;
    return PopScope(
      canPop: !blockPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Hand the device back to a teacher to exit.'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: EdgeScaffold(
        body: ColoredBox(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: _run.current.mode == ActivityMode.shoot
                    ? _shootView(context)
                    : _galleryView(context),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _onStaffCornerTap,
                  child: const SizedBox(width: 56, height: 56),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shoot phase ──────────────────────────────────────────────────────

  Widget _shootView(BuildContext context) {
    final c = _controller;
    switch (_cam) {
      case _CamStatus.ready when c != null && c.value.isInitialized:
        return Stack(
          fit: StackFit.expand,
          children: [
            _preview(c),
            Positioned(top: 0, left: 0, right: 0, child: _instructionBar()),
            Positioned(bottom: 0, left: 0, right: 0, child: _shootControls()),
          ],
        );
      case _CamStatus.denied:
        return _CamMessage(
          icon: Icons.no_photography_outlined,
          title: 'Camera access needed',
          message: 'Allow the camera so you can take photos.',
          actionLabel: 'Try again',
          onAction: () {
            setState(() => _cam = _CamStatus.initializing);
            unawaited(_initCamera());
          },
        );
      case _CamStatus.unavailable:
        return const _CamMessage(
          icon: Icons.videocam_off_outlined,
          title: 'No camera here',
          message: 'This device has no camera available.',
        );
      case _CamStatus.initializing:
      case _CamStatus.ready:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
    }
  }

  Widget _preview(CameraController c) {
    final size = c.value.previewSize;
    if (size == null) return const ColoredBox(color: Colors.black);
    // Full-bleed cover. previewSize is landscape-oriented; swap for the
    // portrait surface so the preview fills without distortion.
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

  Widget _instructionBar() {
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.prompt,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_photos.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
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

  Widget _shootControls() {
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Row(
            children: [
              const SizedBox(width: 72),
              Expanded(
                child: Center(
                  child: _ShutterButton(busy: _shooting, onTap: _shoot),
                ),
              ),
              SizedBox(
                width: 72,
                child: TextButton(
                  onPressed: _finishShooting,
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gallery phase ────────────────────────────────────────────────────

  Widget _galleryView(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              _photos.isEmpty
                  ? 'No photos this time'
                  : 'Everything you captured',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${_photos.length} ${_photos.length == 1 ? 'photo' : 'photos'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _photos.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.photo_outlined,
                      color: Colors.white24,
                      size: 64,
                    ),
                  )
                : PhotoGalleryView(photos: _photos),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Hand the device back to your teacher.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-screen dynamic grid of captured photos. Public + bytes-in so it
/// is testable without a camera.
class PhotoGalleryView extends StatelessWidget {
  const PhotoGalleryView({required this.photos, super.key});

  final List<Uint8List> photos;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: photos.length,
      itemBuilder: (context, i) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          photos[i],
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white12),
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class _CamMessage extends StatelessWidget {
  const _CamMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
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
