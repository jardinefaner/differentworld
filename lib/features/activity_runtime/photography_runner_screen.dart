import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/collage_gallery.dart';
import 'package:differentworld/features/activity_runtime/justified_gallery.dart';
import 'package:differentworld/features/activity_runtime/photography.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/inline_editable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

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
/// only the ones marked "share" become the submission. A shared shot is
/// PERSISTED the moment its heart is tapped — uploaded to the private
/// person-photos bucket and written as an attachment under
/// `(kind: 'photo_session', id: _sessionId)`, following the stable-
/// attachment-id contract (offline-safe: a `pending:` token queues when
/// there's no network). Un-shared keepers stay persisted. In-memory
/// bytes drive the live filmstrip/preview; the retained `XFile` is what
/// gets uploaded. The next slice (a "present to the room" cast) reads
/// those rows via `attachmentsForEntityProvider(photoSessionEntity)`.
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
///
/// `bytes` stays in memory for the live filmstrip / preview (fast, no
/// re-read). `file` is the `camera` package's `XFile` from `takePicture`
/// — retained so a SHARED shot can be persisted to Storage through the
/// stable-attachment-id contract without a temp-file round-trip.
/// `attachmentId` is the row id once persisted (null until the heart is
/// tapped); it MUST equal the id passed to `uploadOnly` so a deferred
/// offline upload patches the right row (see CLAUDE.md "Offline
/// attachment uploads").
class _Shot {
  _Shot(this.bytes, {required this.file, required this.aspectRatio})
    : capturedAt = DateTime.now();

  final Uint8List bytes;
  final XFile file;
  final double aspectRatio;
  final DateTime capturedAt;
  String reflection = '';
  bool shared = false;
  String? attachmentId;
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

  /// The owner id for every photo persisted from THIS run. Shared shots
  /// are stored as attachments under `(kind: 'photo_session', id:
  /// _sessionId)` — a free-string entityKind, no schema change. Public
  /// so the next slice (a "present to the room" cast) can read
  /// `attachmentsForEntityProvider((kind: 'photo_session', id:
  /// sessionId))`.
  final String _sessionId = const Uuid().v4();

  /// Owner key for the persisted shared photos this run.
  AttachmentEntity get photoSessionEntity =>
      (kind: 'photo_session', id: _sessionId);

  /// Everything captured this session (newest last). Offline-first.
  final List<_Shot> _shots = <_Shot>[];

  /// When non-null, the full-screen contextual viewer is open at this
  /// index (an in-screen overlay, not a route; back closes it first).
  int? _viewingIndex;
  PageController? _viewerPage;

  /// Showing the shared photos full-screen as "the findings".
  bool _presenting = false;

  // ── Room slideshow (the present-to-the-wall surface) ─────────────────
  // One shared photo at a time, full-bleed, auto-advancing on a timer the
  // teacher can pause. ALL three are created in [_openPresentation] and
  // torn down in [_closePresentation] + `dispose()` — never leak a Timer.
  PageController? _slidePage;
  Timer? _slideTimer;
  int _slideIndex = 0;
  bool _slidePaused = false;

  /// How long each shared photo holds before the slideshow advances.
  static const Duration _slideInterval = Duration(seconds: 4);

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
    _slideTimer?.cancel();
    _viewerPage?.dispose();
    _slidePage?.dispose();
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
      setState(() => _shots.add(_Shot(bytes, file: shot, aspectRatio: ar)));
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

  /// Toggle a shot's share state AND persist it the first time it's
  /// shared. This is the data-loss fix: only the curated keepers (the
  /// shared shots) are uploaded — kids may take 50, we keep what they
  /// chose. The upload follows the stable-attachment-id contract
  /// (CLAUDE.md "Offline attachment uploads"): the same `attId` goes to
  /// BOTH `uploadOnly(entityId:)` and `attachments.add(id:)`, so a
  /// deferred offline upload's queue-side `updateUrl(id)` patches THIS
  /// row.
  ///
  /// `shot.attachmentId` is the de-dupe guard: once set, toggling the
  /// heart off and on again never re-uploads. Un-sharing leaves the
  /// persisted row in place (simplest, and avoids a destructive delete
  /// of a child's photo that PowerSync would have to round-trip) — the
  /// in-memory `shared` flag still drives the present/curate UI.
  void _toggleShared(_Shot shot) {
    final nowShared = !shot.shared;
    setState(() => shot.shared = nowShared);
    if (nowShared && shot.attachmentId == null) {
      // Optimistic + fire-and-forget. uploadOnly is offline-safe (returns
      // a `pending:` token and queues when there's no network), so we
      // never block the heart tap on a round-trip.
      shot.attachmentId = const Uuid().v4();
      unawaited(_persistShot(shot));
    }
  }

  /// Upload one shared shot's bytes to the private person-photos bucket
  /// and write the attachment row. No PII in logs — errors go to
  /// FlutterError (gated/scrubbed there), never a raw print of the path.
  Future<void> _persistShot(_Shot shot) async {
    final attId = shot.attachmentId;
    if (attId == null) return;
    final service = ref.read(photoServiceProvider);
    final attachments = ref.read(attachmentActionsProvider);
    try {
      final url = await service.uploadOnly(
        entityKind: 'attachment',
        entityId: attId,
        picked: shot.file,
      );
      await attachments.add(
        id: attId,
        entityKind: photoSessionEntity.kind,
        entityId: photoSessionEntity.id,
        url: url,
        caption: shot.reflection.trim().isEmpty ? null : shot.reflection.trim(),
      );
    } on Object catch (e, st) {
      // Roll back the de-dupe marker so a later re-share can retry the
      // upload rather than being silently skipped forever.
      shot.attachmentId = null;
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'photography'),
      );
    }
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
          _closePresentation();
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
                onPressed: _openPresentation,
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
              onTap: () => _toggleShared(s),
            ),
          ),
        ],
      ),
    );
  }

  // ── Room slideshow lifecycle ─────────────────────────────────────────

  /// The shared keepers, in capture order — the reel the slideshow plays.
  /// Re-derived each call (cheap; the curate UI is gone while presenting so
  /// the set is stable for the run, but deriving keeps it always-correct).
  List<_Shot> get _sharedShots =>
      _shots.where((s) => s.shared).toList(growable: false);

  /// Open the present-to-the-wall slideshow: create the [PageController],
  /// reset to the first photo, start auto-advance. Defensive empty guard
  /// (the button already requires ≥1 shared). Idempotent on the controller
  /// (dispose any stale one first) so a re-open never leaks.
  void _openPresentation() {
    if (_sharedShots.isEmpty) return;
    _slidePage?.dispose();
    _slidePage = PageController();
    _slideIndex = 0;
    _slidePaused = false;
    setState(() => _presenting = true);
    _scheduleSlide();
  }

  /// Close the slideshow: stop the timer, drop the controller, return to the
  /// gallery. Safe to call from PopScope back, the in-screen back button, or
  /// any path — cancels the timer so we never leak it on exit.
  void _closePresentation() {
    _slideTimer?.cancel();
    _slideTimer = null;
    final page = _slidePage;
    _slidePage = null;
    // Dispose after the frame so a PageView still attached this build isn't
    // torn out from under itself.
    WidgetsBinding.instance.addPostFrameCallback((_) => page?.dispose());
    if (mounted) {
      setState(() {
        _presenting = false;
        _slidePaused = false;
      });
    }
  }

  /// (Re)start the auto-advance timer. Always cancels the prior one first so
  /// two timers can never run at once. Every tick guards on `mounted` and on
  /// the still-presenting / not-paused state, and loops back to the first
  /// photo after the last so an unattended wall display runs forever.
  void _scheduleSlide() {
    _slideTimer?.cancel();
    _slideTimer = Timer.periodic(_slideInterval, (_) {
      if (!mounted || !_presenting || _slidePaused) return;
      final count = _sharedShots.length;
      if (count == 0) return;
      _goSlide((_slideIndex + 1) % count);
    });
  }

  /// Move the slideshow to [target] (already a valid index). Animates the
  /// PageView; `onPageChanged` keeps `_slideIndex` in lockstep so taps,
  /// swipes, and the timer all agree on where we are.
  void _goSlide(int target) {
    if (!mounted) return;
    final page = _slidePage;
    final count = _sharedShots.length;
    if (page == null || !page.hasClients || count == 0) return;
    final next = target.clamp(0, count - 1);
    unawaited(
      page.animateToPage(
        next,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      ),
    );
  }

  /// Manual prev/next (tap-zones + swipe land here via [_goSlide]). Wraps at
  /// both ends so the room never hits a dead edge. A manual move also resets
  /// the auto-advance clock so the photo you jumped to gets its full dwell.
  void _stepSlide(int delta) {
    final count = _sharedShots.length;
    if (count == 0) return;
    _goSlide((_slideIndex + delta + count) % count);
    if (!_slidePaused) _scheduleSlide();
  }

  /// Tap the stage to pause/resume auto-advance — the teacher's "hold on this
  /// one" gesture. Manual prev/next still works while paused.
  void _toggleSlidePause() {
    if (!mounted) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _slidePaused = !_slidePaused);
    if (_slidePaused) {
      _slideTimer?.cancel();
      _slideTimer = null;
    } else {
      _scheduleSlide();
    }
  }

  /// The room slideshow — the SHARED photos, one at a time, full-bleed on a
  /// dark stage, auto-advancing. THIS is the moment the teacher mirrors the
  /// phone to the wall (AirPlay/HDMI/Cast). Presents from in-memory bytes
  /// (`Image.memory`) so it's instant and offline-proof — never the network
  /// URL. Tap the stage to pause; tap-zones / swipe go prev/next.
  Widget _presentation(BuildContext context) {
    final theme = Theme.of(context);
    final shared = _sharedShots;

    // Defensive: the present button requires ≥1 shared, but if the reel is
    // somehow empty, show a calm message + a way back rather than a void.
    if (shared.isEmpty) {
      return SafeArea(
        child: Stack(
          children: [
            const Center(
              child: Text(
                'Nothing shared yet',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _closePresentation,
              ),
            ),
          ],
        ),
      );
    }

    final current = _slideIndex.clamp(0, shared.length - 1);
    final reflection = shared[current].reflection.trim();

    // The stage is a raw immersive canvas (this file is on the theme
    // allowlist) — a hardcoded dark stage is correct here; chrome stays
    // white-on-dark to match the rest of the present controls.
    return Stack(
      // Conditional children (caption, pause badge) → stable keys so an
      // appearing sibling can't poison Element identity (CLAUDE.md "Stack
      // children without keys"). The PageView is byte-backed so a rebuild is
      // cheap, but keying is the house rule regardless.
      children: [
        // Full-bleed photo reel. Swipe = manual prev/next; onPageChanged is
        // the single source of truth for the live index.
        Positioned.fill(
          key: const ValueKey('photo-present-pageview'),
          child: PageView.builder(
            controller: _slidePage,
            itemCount: shared.length,
            onPageChanged: (i) {
              if (!mounted) return;
              setState(() => _slideIndex = i);
            },
            itemBuilder: (_, i) => Center(
              child: Image.memory(
                shared[i].bytes,
                fit: BoxFit.contain, // whole photo, full-bleed, no crop
                gaplessPlayback: true,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colors.black),
              ),
            ),
          ),
        ),
        // Tap zones: centre tap pauses/resumes; left third = prev, right
        // third = next. Opaque so a childless detector actually hit-tests.
        Positioned.fill(
          key: const ValueKey('photo-present-tapzones'),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _stepSlide(-1),
                ),
              ),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleSlidePause,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _stepSlide(1),
                ),
              ),
            ],
          ),
        ),
        // Caption — the learner's reflection over a legible bottom scrim.
        if (reflection.isNotEmpty)
          Positioned(
            key: const ValueKey('photo-present-caption'),
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
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
                    padding: const EdgeInsets.fromLTRB(28, 56, 28, 28),
                    child: Text(
                      reflection,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Back — top-left, over a soft scrim so it reads on a bright photo.
        Positioned(
          key: const ValueKey('photo-present-back'),
          top: 4,
          left: 4,
          child: SafeArea(
            child: _PresentChromeButton(
              icon: Icons.arrow_back,
              tooltip: 'Back to the gallery',
              onTap: _closePresentation,
            ),
          ),
        ),
        // Paused badge — top-centre, so "we're holding here" reads across the
        // room. Only while paused.
        if (_slidePaused)
          Positioned(
            key: const ValueKey('photo-present-paused'),
            top: 4,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.pause, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Paused',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Progress — "3 / 12" + a row of dots, bottom-centre, over a scrim so
        // it survives a bright photo even with no caption.
        Positioned(
          key: const ValueKey('photo-present-progress'),
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SlideProgress(
                  index: current,
                  count: shared.length,
                  // Hide the dots behind the caption scrim's text, but always
                  // show the counter; the counter sits low-left so it dodges
                  // a centred caption.
                  showDots: reflection.isEmpty,
                  theme: theme,
                ),
              ),
            ),
          ),
        ),
      ],
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
                      onPressed: () => _toggleShared(_shots[_viewingIndex!]),
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
                onCommit: (t) async {
                  setState(() => s.reflection = t);
                  // If this shot is already a persisted keeper, push the
                  // edited note onto its attachment row's caption so a
                  // note typed AFTER sharing isn't lost. Fire-and-forget,
                  // offline-safe (Drift write queues like any other).
                  final attId = s.attachmentId;
                  if (attId != null) {
                    final caption = t.trim().isEmpty ? null : t.trim();
                    unawaited(
                      ref
                          .read(attachmentActionsProvider)
                          .updateCaption(id: attId, caption: caption),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round, scrimmed chrome button for the present stage — readable over a
/// bright photo (the back arrow). White-on-dark to match the raw stage.
class _PresentChromeButton extends StatelessWidget {
  const _PresentChromeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

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
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// The slideshow's subtle progress — a "3 / 12" counter plus an optional row
/// of dots, both inside a soft pill so they read on any photo. White-on-dark
/// (raw present stage). [showDots] is suppressed when a caption owns the
/// bottom band, leaving just the counter.
class _SlideProgress extends StatelessWidget {
  const _SlideProgress({
    required this.index,
    required this.count,
    required this.showDots,
    required this.theme,
  });

  final int index;
  final int count;
  final bool showDots;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Cap the rendered dots so a 30-photo reel doesn't overflow a phone width;
    // the counter always carries the exact position.
    const maxDots = 12;
    final dots = count <= maxDots;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${index + 1} / $count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            if (showDots && dots) ...[
              const SizedBox(width: 12),
              for (var i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
            ],
          ],
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
