import 'dart:async';

import 'package:camera/camera.dart';
import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/photography.dart';
import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/inline_editable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// `/activity/photo?prompt=...` — the Photography activity (docs/
/// ACTIVITY_RUNTIME.md §5 + SUBMISSIONS.md). Opens straight to a
/// full-screen camera with the instruction in the overlay; shoot as many
/// as you like; Done → a gallery that's a **curate** surface: pick which
/// photos to share, and tap any photo for a full-screen view laid out with
/// its context + an editable reflection. Kid-mode locked.
///
/// SUBMISSIONS model (offline-first): every capture stays on the device;
/// only the ones the learner marks "share" become the submission. This
/// slice is on-device / in-session — the upload of shared photos to
/// Storage + the entries/attachments rows + the teacher aggregate are the
/// next slices. Photos are held as in-memory bytes (web-safe, no dart:io).
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

/// One captured photo + the learner's choices about it. Local + mutable;
/// `shared` is the opt-in that decides what becomes the submission.
class _Shot {
  _Shot(this.bytes) : capturedAt = DateTime.now();

  final Uint8List bytes;
  final DateTime capturedAt;
  String reflection = '';
  bool shared = false;
}

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

  /// Everything captured this session (newest last). Offline-first: these
  /// never leave the device unless `shared` is set and a future submit
  /// uploads them.
  final List<_Shot> _shots = <_Shot>[];

  /// When non-null, the full-screen contextual viewer is open at this
  /// index. The viewer is an in-screen overlay (NOT a route push — the
  /// kid-mode redirect pins us to this route).
  int? _viewingIndex;
  PageController? _viewerPage;

  // Kid-mode lockdown — notifiers cached in initState (ref is unsafe in
  // dispose); the screen drives its own lock via _staffUnlocked.
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
    _viewerPage?.dispose();
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
      setState(() => _shots.add(_Shot(bytes)));
      unawaited(HapticFeedback.mediumImpact());
    } on Object catch (_) {
      // A single dropped frame isn't fatal — keep the camera live.
    } finally {
      if (mounted) setState(() => _shooting = false);
    }
  }

  void _finishShooting() {
    _disposeCamera();
    setState(() => _run.advance()); // → gallery / curate
  }

  void _openViewer(int i) {
    _viewerPage?.dispose();
    _viewerPage = PageController(initialPage: i);
    setState(() => _viewingIndex = i);
  }

  void _closeViewer() {
    setState(() => _viewingIndex = null);
    final c = _viewerPage;
    _viewerPage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => c?.dispose());
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
        // Back closes the viewer first; only then is it blocked at the
        // activity level.
        if (_viewingIndex != null) {
          _closeViewer();
          return;
        }
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
              if (_viewingIndex != null && _viewingIndex! < _shots.length)
                Positioned.fill(child: _viewer(context)),
              // Staff corner stays topmost so it works even over the viewer.
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
              if (_shots.isNotEmpty)
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
                        '${_shots.length}',
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

  // ── Gallery / curate phase ───────────────────────────────────────────

  Widget _galleryView(BuildContext context) {
    final theme = Theme.of(context);
    final shared = _shots.where((s) => s.shared).length;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              _shots.isEmpty ? 'No photos this time' : 'Pick what to share',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (_shots.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${_shots.length} captured · $shared to share',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: _shots.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.photo_outlined,
                      color: Colors.white24,
                      size: 64,
                    ),
                  )
                : _curateGrid(),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              shared == 0
                  ? 'Tap a photo to look closer; tap the heart to share it.'
                  : '$shared shared — your teacher will see these.',
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

  Widget _curateGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _shots.length,
      itemBuilder: (context, i) {
        final s = _shots[i];
        return GestureDetector(
          onTap: () => _openViewer(i),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  s.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) =>
                      const ColoredBox(color: Colors.white12),
                ),
              ),
              if (s.shared)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.pinkAccent, width: 3),
                      ),
                    ),
                  ),
                ),
              if (s.reflection.trim().isNotEmpty)
                const Positioned(
                  left: 8,
                  bottom: 8,
                  child: Icon(
                    Icons.sticky_note_2,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: _ShareBadge(
                  shared: s.shared,
                  onTap: () => setState(() => s.shared = !s.shared),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Full-screen contextual viewer ────────────────────────────────────

  Widget _viewer(BuildContext context) {
    final page = _viewerPage;
    if (page == null) return const SizedBox.shrink();
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          // Commit any in-progress reflection before a swipe moves the
          // page — unfocusing fires InlineEditableText's commit + tears
          // down its dim overlay, so a mid-edit swipe can't orphan it.
          NotificationListener<ScrollStartNotification>(
            onNotification: (_) {
              FocusManager.instance.primaryFocus?.unfocus();
              return false;
            },
            child: PageView.builder(
              controller: page,
              itemCount: _shots.length,
              onPageChanged: (i) => setState(() => _viewingIndex = i),
              itemBuilder: (_, i) => _viewerPageView(_shots[i]),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: _closeViewer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewerPageView(_Shot s) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Image.memory(
            s.bytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _viewerContext(s)),
      ],
    );
  }

  Widget _viewerContext(_Shot s) {
    // The context the photo is laid out WITH: the activity, its prompt,
    // when it was taken — plus the learner's editable reflection.
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black, Colors.black87, Colors.transparent],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_run.activity.title} · ${timeOfDay(s.capturedAt)}',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                widget.prompt,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              InlineEditableText(
                value: s.reflection,
                placeholder: 'Add a note about this photo…',
                semanticLabel: 'Reflection',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                placeholderStyle: const TextStyle(
                  color: Colors.white54,
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                onCommit: (t) async => setState(() => s.reflection = t),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => s.shared = !s.shared),
                  icon: Icon(
                    s.shared ? Icons.favorite : Icons.favorite_border,
                  ),
                  label: Text(s.shared ? 'Sharing this' : 'Share this'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A read-only grid of photo bytes — reserved for the teacher / family
/// aggregate views (SUBMISSIONS.md Slice C). Public + bytes-in so it's
/// testable without a camera.
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

class _ShareBadge extends StatelessWidget {
  const _ShareBadge({required this.shared, required this.onTap});

  final bool shared;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Icon(
          shared ? Icons.favorite : Icons.favorite_border,
          color: shared ? Colors.pinkAccent : Colors.white,
          size: 22,
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
