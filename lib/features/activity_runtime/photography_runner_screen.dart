import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/collage_gallery.dart';
import 'package:differentworld/features/activity_runtime/justified_gallery.dart';
import 'package:differentworld/features/activity_runtime/photography.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/inline_editable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// `/activity/photo?prompt=...` — the Photography activity (docs/
/// ACTIVITY_RUNTIME.md §5 + SUBMISSIONS.md). Opens straight into a
/// kid-friendly camera: the prompt is an immersive "mission", a filmstrip
/// of your shots rides above the shutter, and flash / flip / pinch-zoom /
/// tap-to-focus enhance the capture. Done → a dynamic masonry gallery
/// (photos kept whole, varied sizes); tap any for a full-screen view with
/// its context + an editable reflection. Teacher-paced (game-show-host
/// model), NOT a locked kid surface — the floating back arrow exits, and
/// back closes an open viewer/presentation first (rubric A6).
///
/// SUBMISSIONS model (offline-first): every capture stays on the device;
/// only the ones marked "share" become the submission. This slice is
/// on-device / in-session — upload + the teacher aggregate are next.
/// Photos are in-memory bytes (web-safe, no dart:io).
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

/// One captured photo + the learner's choices about it. `aspectRatio`
/// (width/height) drives the masonry so photos show whole at their true
/// shape. `shared` is the opt-in that becomes the submission.
class _Shot {
  _Shot(this.bytes, {required this.aspectRatio}) : capturedAt = DateTime.now();

  final Uint8List bytes;
  final double aspectRatio;
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

  // Camera capabilities.
  CameraLensDirection _lens = CameraLensDirection.back;
  FlashMode _flash = FlashMode.off;
  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _baseZoom = 1;
  Offset? _focusPoint; // local tap point for the focus ring
  Timer? _focusTimer;

  final ScrollController _filmstrip = ScrollController();

  /// Everything captured this session (newest last). Offline-first.
  final List<_Shot> _shots = <_Shot>[];

  /// When non-null, the full-screen contextual viewer is open at this
  /// index (an in-screen overlay, not a route; back closes it first).
  int? _viewingIndex;
  PageController? _viewerPage;

  /// Showing the shared photos full-screen as "the findings".
  bool _presenting = false;

  @override
  void initState() {
    super.initState();
    // Observe lifecycle for the CAMERA only (release on background,
    // re-init on resume) — this is a teacher-paced break, not a locked
    // kid surface; the floating back arrow exits.
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded; re-init on resume if shooting.
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
    _focusTimer?.cancel();
    _viewerPage?.dispose();
    _filmstrip.dispose();
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
      final cam = cams.firstWhere(
        (c) => c.lensDirection == _lens,
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
      // Capability ranges + restore flash for the new controller.
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = await controller.getMaxZoomLevel();
      _zoom = _minZoom;
      try {
        await controller.setFlashMode(_flash);
      } on Object catch (_) {
        // Some lenses (front) don't support flash — ignore.
      }
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _cam = _CamStatus.ready;
      });
    } on Object catch (_) {
      if (mounted) setState(() => _cam = _CamStatus.unavailable);
    } finally {
      _initInFlight = false;
    }
  }

  void _disposeCamera() {
    final c = _controller;
    _controller = null;
    // Reset the in-flight guard: backgrounding DURING init (permission dialog
    // up, _controller still null) would otherwise leave this true and make
    // the resume-time _initCamera early-return forever (camera stuck). The
    // init's own `if (!mounted)` guards dispose a late-finishing controller.
    _initInFlight = false;
    unawaited(c?.dispose());
  }

  Future<double> _aspectRatioOf(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final w = frame.image.width;
      final h = frame.image.height;
      frame.image.dispose();
      codec.dispose();
      if (w <= 0 || h <= 0) return 0.75;
      return w / h;
    } on Object catch (_) {
      return 0.75; // sensible portrait default
    }
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
      final ar = await _aspectRatioOf(bytes);
      if (!mounted) return;
      setState(() => _shots.add(_Shot(bytes, aspectRatio: ar)));
      unawaited(HapticFeedback.mediumImpact());
      // Slide the filmstrip to the freshest shot.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _filmstrip.hasClients) {
          unawaited(
            _filmstrip.animateTo(
              _filmstrip.position.maxScrollExtent,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
            ),
          );
        }
      });
    } on Object catch (_) {
      // A single dropped frame isn't fatal — keep the camera live.
    } finally {
      if (mounted) setState(() => _shooting = false);
    }
  }

  Future<void> _switchCamera() async {
    _lens = _lens == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    _disposeCamera();
    setState(() => _cam = _CamStatus.initializing);
    await _initCamera();
  }

  Future<void> _cycleFlash() async {
    const order = [FlashMode.off, FlashMode.auto, FlashMode.always];
    final next = order[(order.indexOf(_flash) + 1) % order.length];
    setState(() => _flash = next);
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setFlashMode(next);
    } on Object catch (_) {
      // Lens doesn't support it — the icon still reflects intent.
    }
  }

  Future<void> _applyZoom(double target) async {
    final clamped = target.clamp(_minZoom, _maxZoom);
    if (clamped == _zoom) return;
    setState(() => _zoom = clamped);
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setZoomLevel(clamped);
    } on Object catch (_) {}
  }

  Future<void> _focusAt(Offset local, Size size) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (size.width <= 0 || size.height <= 0) return;
    setState(() => _focusPoint = local);
    _focusTimer?.cancel();
    _focusTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _focusPoint = null);
    });
    final p = Offset(
      (local.dx / size.width).clamp(0.0, 1.0),
      (local.dy / size.height).clamp(0.0, 1.0),
    );
    try {
      await c.setFocusPoint(p);
      await c.setExposurePoint(p);
    } on Object catch (_) {}
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

  @override
  Widget build(BuildContext context) {
    // Back closes an open overlay first (the full-screen viewer, then the
    // presentation), and otherwise exits the activity — no lock; the
    // floating back arrow gets you out from any phase.
    final canExit = _viewingIndex == null && !_presenting;
    return PopScope(
      canPop: canExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_viewingIndex != null) {
          _closeViewer();
        } else if (_presenting) {
          setState(() => _presenting = false);
        }
      },
      child: EdgeScaffold(
        body: ColoredBox(
          color: Colors.black,
          child: Stack(
            children: [
              Positioned.fill(
                child: _run.current.mode == ActivityMode.shoot
                    ? _shootView(context)
                    : (_presenting
                          ? _presentation(context)
                          : _galleryView(context)),
              ),
              if (_viewingIndex != null && _viewingIndex! < _shots.length)
                Positioned.fill(child: _viewer(context)),
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
        return LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            return Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onScaleStart: (_) => _baseZoom = _zoom,
                  onScaleUpdate: (d) {
                    if (d.pointerCount >= 2) {
                      unawaited(_applyZoom(_baseZoom * d.scale));
                    }
                  },
                  onTapUp: (d) => unawaited(_focusAt(d.localPosition, size)),
                  child: _preview(c),
                ),
                if (_focusPoint != null) _FocusRing(point: _focusPoint!),
                Positioned(top: 0, left: 0, right: 0, child: _topBar()),
                Positioned(bottom: 0, left: 0, right: 0, child: _bottomBar()),
              ],
            );
          },
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
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _MissionBanner(prompt: widget.prompt)),
              const SizedBox(width: 8),
              _CapButton(
                icon: _flash == FlashMode.off
                    ? Icons.flash_off
                    : _flash == FlashMode.auto
                    ? Icons.flash_auto
                    : Icons.flash_on,
                active: _flash != FlashMode.off,
                tooltip: 'Flash',
                onTap: () => unawaited(_cycleFlash()),
              ),
              const SizedBox(width: 8),
              _CapButton(
                icon: Icons.cameraswitch_outlined,
                tooltip: 'Flip camera',
                onTap: () => unawaited(_switchCamera()),
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
            if (_shots.isNotEmpty) _filmstripRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
              child: Row(
                children: [
                  const SizedBox(width: 64),
                  Expanded(
                    child: Center(
                      child: _ShutterButton(busy: _shooting, onTap: _shoot),
                    ),
                  ),
                  SizedBox(
                    width: 64,
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
          ],
        ),
      ),
    );
  }

  Widget _filmstripRow() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        controller: _filmstrip,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _shots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final s = _shots[i];
          return GestureDetector(
            onTap: () => _openViewer(i),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    s.bytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, _, _) => const SizedBox(
                      width: 56,
                      height: 56,
                    ),
                  ),
                ),
                if (s.shared)
                  const Positioned(
                    right: 3,
                    top: 3,
                    child: Icon(
                      Icons.favorite,
                      size: 14,
                      color: Colors.pinkAccent,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _finishShooting() {
    _disposeCamera();
    setState(() => _run.advance()); // → gallery / curate
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
          const SizedBox(height: 8),
          Expanded(
            child: _shots.isEmpty
                ? const Center(
                    child: Icon(
                      Icons.photo_outlined,
                      color: Colors.white24,
                      size: 64,
                    ),
                  )
                : CollageGallery(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tiles: [
                      for (var i = 0; i < _shots.length; i++)
                        JustifiedTile(
                          aspectRatio: _ar(_shots[i]),
                          child: _galleryTile(_shots[i], i),
                        ),
                    ],
                  ),
          ),
          if (shared > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: FilledButton.icon(
                onPressed: () => setState(() => _presenting = true),
                icon: const Icon(Icons.slideshow_outlined),
                label: Text(
                  'Present $shared ${shared == 1 ? 'photo' : 'photos'}',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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

  double _ar(_Shot s) => s.aspectRatio <= 0 ? 0.75 : s.aspectRatio;

  /// A curate tile: the photo whole (the justified gallery sizes the box to
  /// the photo's aspect ratio, so cover == no crop) + a share heart + a
  /// note dot. Square edges so the rows pack tight (the Google-Photos look).
  Widget _galleryTile(_Shot s, int i) {
    return GestureDetector(
      onTap: () => _openViewer(i),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            s.bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.white12),
          ),
          if (s.shared)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.pinkAccent, width: 3),
                  ),
                ),
              ),
            ),
          if (s.reflection.trim().isNotEmpty)
            const Positioned(
              left: 6,
              bottom: 6,
              child: Icon(Icons.sticky_note_2, size: 16, color: Colors.white),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: _ShareBadge(
              shared: s.shared,
              onTap: () => setState(() => s.shared = !s.shared),
            ),
          ),
        ],
      ),
    );
  }

  /// The findings presentation — the SHARED photos, full-screen, in the
  /// justified gallery (the "show everyone" view). Single-device for now;
  /// cross-device when submissions sync (SUBMISSIONS.md Slice B/C).
  Widget _presentation(BuildContext context) {
    final theme = Theme.of(context);
    final sharedIdx = [
      for (var i = 0; i < _shots.length; i++)
        if (_shots[i].shared) i,
    ];
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => setState(() => _presenting = false),
                ),
                Expanded(
                  child: Text(
                    widget.prompt,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sharedIdx.isEmpty
                ? const Center(
                    child: Text(
                      'Nothing shared yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                : CollageGallery(
                    padding: const EdgeInsets.all(4),
                    tiles: [
                      for (final i in sharedIdx)
                        JustifiedTile(
                          aspectRatio: _ar(_shots[i]),
                          child: GestureDetector(
                            onTap: () => _openViewer(i),
                            child: Image.memory(
                              _shots[i].bytes,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, _, _) =>
                                  const ColoredBox(color: Colors.white12),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
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
          // page — unfocusing tears down InlineEditableText's overlay.
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_viewingIndex != null && _viewingIndex! < _shots.length)
                    IconButton(
                      tooltip: 'Share this',
                      icon: Icon(
                        _shots[_viewingIndex!].shared
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: _shots[_viewingIndex!].shared
                            ? Colors.pinkAccent
                            : Colors.white,
                        size: 28,
                      ),
                      onPressed: () => setState(
                        () => _shots[_viewingIndex!].shared =
                            !_shots[_viewingIndex!].shared,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _closeViewer,
                  ),
                ],
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
            fit: BoxFit.contain, // whole photo, full screen
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _viewerContext(s)),
      ],
    );
  }

  Widget _viewerContext(_Shot s) {
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
            ],
          ),
        ),
      ),
    );
  }
}

/// The immersive prompt — a warm "mission" card the kid reads on open.
class _MissionBanner extends StatelessWidget {
  const _MissionBanner({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.auto_awesome,
              color: Colors.amberAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YOUR MISSION',
                  style: TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  prompt,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
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

/// A round translucent camera-capability button (flash, flip).
class _CapButton extends StatelessWidget {
  const _CapButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.active = false,
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

/// A masonry tile: the photo whole at its aspect ratio + a share heart.
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

/// A brief focus ring drawn where the learner tapped to focus.
class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.point});

  final Offset point;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: point.dx - 36,
      top: point.dy - 36,
      child: IgnorePointer(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amberAccent, width: 2),
          ),
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
      behavior: HitTestBehavior.opaque,
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
