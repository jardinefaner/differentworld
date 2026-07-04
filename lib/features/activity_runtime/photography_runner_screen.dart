import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:differentworld/features/activity_runtime/activity_script.dart';
import 'package:differentworld/features/activity_runtime/collage_gallery.dart';
import 'package:differentworld/features/activity_runtime/justified_gallery.dart';
import 'package:differentworld/features/activity_runtime/photography.dart';
import 'package:differentworld/features/kid_mode/kid_mode_exit_dialog.dart';
import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/photo_upload_queue.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/camera_chrome.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/inline_editable_text.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// `/activity/photo?prompt=...` — the Photography activity (docs/
/// ACTIVITY_RUNTIME.md §5 + SUBMISSIONS.md). Opens straight into a
/// kid-friendly camera: the prompt is an immersive "mission", a filmstrip
/// of your shots rides above the shutter, and flash / flip / pinch-zoom /
/// tap-to-focus enhance the capture. Done → a dynamic masonry gallery
/// (photos kept whole, varied sizes); tap any for a full-screen view with
/// its context + an editable reflection. Teacher-paced (game-show-host
/// model) by default — the floating back arrow exits, and back closes an
/// open viewer/presentation first (rubric A6).
///
/// KID LOCK (opt-in): the runner is ALSO teacher-run, so kid mode is NOT
/// forced. A lock toggle in the camera top bar ("Hand to the kids") enters
/// kid mode the same way the reference kid screens do
/// (`action_words_kid_screen` / `draw_self_screen`): `kidModeProvider.enter()`
/// + `kidModeLockedRouteProvider.pin('/activity/photo')`. AppShell then strips
/// the omnibox bar + drawer, the router redirect bounces away-nav back to the
/// pinned route, and a `PopScope(canPop: false)` blocks system-back — so a
/// child can shoot but can't escape to staff screens. A hidden staff 5-tap on
/// the top-left 56×56 corner opens `showKidModeExitDialog` (staff PIN, or the
/// 5-tap alone when no PIN is set); on success the lock releases and the
/// teacher reclaims the phone. The camera keeps running the whole time — the
/// lock never touches the controller. Dispose exits kid mode if still locked,
/// so leaving never strands the whole app in kid mode.
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
///
/// TIMED PER-CHILD TURNS (docs/PHOTO_TURNS, opt-in via [turnSubjectId]):
/// the same runner doubles as one child's locked turn. When [turnSubjectId]
/// is set, the kid-lock auto-engages on mount, a [turnDuration] countdown
/// shows in the camera chrome with the child's name + mission, and EVERY
/// shot persisted this turn is stamped `captured_by_subject_id =
/// turnSubjectId` + `schedule_block_id = scheduleBlockId` (the new tag axes)
/// so each photo files into that child's progress folder. At 0 the camera
/// hard-stops behind a "Time's up — give the phone to your teacher" overlay;
/// staff reclaim via the hidden corner gesture and [onTurnEnded] pops back to
/// the "Whose turn?" picker. Without [turnSubjectId] the runner behaves
/// exactly as the plain Photo Studio (untouched).
class PhotographyRunnerScreen extends ConsumerStatefulWidget {
  const PhotographyRunnerScreen({
    this.prompt = 'Capture what you see',
    this.turnSubjectId,
    this.turnSubjectName,
    this.scheduleBlockId,
    this.turnDuration = const Duration(minutes: 5),
    this.onTurnEnded,
    super.key,
  });

  final String prompt;

  /// When non-null, this run is ONE child's timed turn. Drives the auto
  /// kid-lock, the countdown, and the per-shot `captured_by_subject_id`
  /// stamp. Null ⇒ the plain, un-timed Photo Studio.
  final String? turnSubjectId;

  /// The child's display name, shown in the timer chrome ("Maya's turn ·
  /// 4:32"). Only read when [turnSubjectId] is set.
  final String? turnSubjectName;

  /// The block this turn belongs to (stamped onto every shot as
  /// `schedule_block_id`). Null for an ad-hoc turn with no block.
  final String? scheduleBlockId;

  /// How long the locked turn lasts before the hard-stop. Defaults to the
  /// 5-minute classroom default; a const so it's tunable per launch.
  final Duration turnDuration;

  /// Called once the turn is OVER and staff have reclaimed the phone (after
  /// the hard-stop, on the staff-corner unlock). The picker uses this to mark
  /// the child done and return to the roster. Null for a standalone turn.
  final VoidCallback? onTurnEnded;

  /// True when launched as a timed per-child turn.
  bool get isTurn => turnSubjectId != null;

  @override
  ConsumerState<PhotographyRunnerScreen> createState() =>
      _PhotographyRunnerScreenState();
}

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
  _Shot(
    this.bytes, {
    required this.file,
    required this.aspectRatio,
    this.capturedBySubjectId,
    this.scheduleBlockId,
  }) : capturedAt = DateTime.now();

  final Uint8List bytes;
  final XFile file;
  final double aspectRatio;
  final DateTime capturedAt;
  String reflection = '';
  bool shared = false;
  String? attachmentId;

  /// The turn's child id + block, SNAPSHOTTED on the shot at capture time —
  /// NOT re-read from `widget` at persist time. A deferred/in-flight
  /// `_persistShot` must stamp the child who actually took the photo even if
  /// the widget were ever recycled with a different turn (hot reload / OS
  /// resurrection). Null in the plain Photo Studio. This is the privacy
  /// guarantee that one child's shot can never file into another's folder.
  final String? capturedBySubjectId;
  final String? scheduleBlockId;
}

class _PhotographyRunnerScreenState
    extends ConsumerState<PhotographyRunnerScreen>
    with WidgetsBindingObserver, CameraSessionMixin {
  late final ActivityRun _run = ActivityRun(
    photographyActivity(prompt: widget.prompt),
  );

  bool _shooting = false;

  // Camera capabilities.
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

  // ── Kid lock (opt-in "Hand to the kids") ─────────────────────────────
  // The pinned route MUST equal the GoRoute path WITHOUT query params: the
  // router redirect compares `state.matchedLocation != lockedRoute`, and
  // matchedLocation is '/activity/photo' even when the URL carries
  // `?prompt=…`. Pinning the prompt'd URL would never match → infinite
  // redirect loop.
  //
  // This is the DEFAULT pin for the plain Photo Studio, reached directly at
  // `/activity/photo`. A TIMED TURN is pushed imperatively ON TOP of the
  // picker's route (`/activity/photo-turns`), so its matchedLocation is the
  // picker's — pinning '/activity/photo' there would make the redirect bounce
  // the whole stack to the plain studio. So in turn mode we pin the LIVE
  // location instead (see `_resolvePinnedRoute`).
  static const String _lockedRoute = '/activity/photo';

  /// The route the kid-lock pins — the location the redirect refuses to leave.
  /// Defaults to [_lockedRoute] (plain studio); a timed turn overwrites it
  /// with the live shell location at lock time so the redirect targets where
  /// the runner actually sits (the picker's `/activity/photo-turns`), not the
  /// plain studio. Captured BEFORE any `ref`/context use in dispose, so dispose
  /// (which clears with `pin(null)`, route-agnostic) never reads it.
  String _pinnedRoute = _lockedRoute;

  /// Notifiers cached EAGERLY in initState — a plain `ref.read` there is
  /// safe, but `ref` in dispose is not (Riverpod: "save the provider state in
  /// a field"). They must NOT be `late final … = ref.read(…)`: a lazy field
  /// first touched from dispose (e.g. fast-back before the engage microtask
  /// fires, then dispose hits `if (_locked)`) would run `ref.read` IN dispose
  /// — the exact forbidden case. Assigning in initState makes the field
  /// already-resolved by the time dispose reads it. Mirrors `draw_self_screen`
  /// / the `KidModeLock` mixin.
  late final KidMode _kidMode;
  late final KidModeLockedRoute _kidLockedRoute;

  /// True once THIS screen has engaged the lock (drives the visible lock
  /// chip + which PopScope branch wins). Mirrors `kidModeProvider` but is a
  /// local flag so dispose never has to read a provider. In a timed turn it's
  /// set SYNCHRONOUSLY in initState so PopScope blocks back from frame 0; the
  /// provider write is what `_engageKidLock` actually performs (guarded by
  /// [_lockEngaged], not this flag).
  bool _locked = false;

  /// Whether the kid-mode PROVIDER write (enter + pin) has fired. Distinct from
  /// [_locked]: a timed turn pre-sets `_locked` for the PopScope guard before
  /// the deferred `_engageKidLock` does the provider write, so the double-engage
  /// guard keys on THIS flag instead.
  bool _lockEngaged = false;

  /// Hidden staff exit: five quick taps in the top-left corner, each within
  /// [_staffTapWindow] of the last, so a kid mashing the corner can't
  /// accumulate. [_exitDialogOpen] is the re-entrancy guard.
  int _staffTapCount = 0;
  Timer? _staffTapReset;
  bool _exitDialogOpen = false;
  static const int _staffTapTarget = 5;
  static const Duration _staffTapWindow = Duration(milliseconds: 800);

  // ── Timed per-child turn (opt-in, when widget.isTurn) ────────────────
  // A single countdown drives the whole turn. It's a one-second periodic
  // Timer (never two at once — _startCountdown cancels first), every tick is
  // mounted-guarded, and it's torn down in dispose AND the instant it hits 0.
  // When it hits 0 we set _timeUp (the hard-stop) and DON'T release the lock —
  // the kid keeps the phone but can't shoot; staff reclaim via the corner.
  Timer? _countdown;

  /// Seconds left in this turn. Seeded from `widget.turnDuration` in
  /// initState; only meaningful when `widget.isTurn`.
  int _secondsLeft = 0;

  /// True once the countdown has reached 0 — the hard-stop. Blocks the
  /// shutter and paints the "Time's up" overlay over the camera.
  bool _timeUp = false;

  @override
  void initState() {
    super.initState();
    // Observe lifecycle for the CAMERA (release on background, re-init on
    // resume) AND, once locked, to re-engage kid mode if the OS resurrects
    // the Activity without rebuilding the tree.
    WidgetsBinding.instance.addObserver(this);
    // Cache the kid-lock notifiers now (a plain read in initState is safe) so
    // dispose never touches `ref`. The .enter() WRITE is deferred to a tap +
    // microtask, not done here — entering on mount would force kid mode (this
    // surface is opt-in / teacher-run by default).
    _kidMode = ref.read(kidModeProvider.notifier);
    _kidLockedRoute = ref.read(kidModeLockedRouteProvider.notifier);
    // A timed turn auto-locks + starts its countdown — the child is handed a
    // phone that's already in their turn.
    if (widget.isTurn) {
      _secondsLeft = widget.turnDuration.inSeconds;
      // Set `_locked` SYNCHRONOUSLY so PopScope blocks system-back from the
      // very first frame — otherwise there's a one-frame window before the
      // post-frame lock fires where `canPop` is true and a fast back escapes
      // the turn. The provider WRITE (kidModeProvider/pin) still defers to the
      // post-frame microtask: initState runs inside the parent's build phase,
      // and kidModeProvider is watched by AppShell, so a synchronous write
      // would trip "modified a provider while building". Pin resolution needs
      // a valid context (GoRouterState), which the post-frame callback has.
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _engageKidLock();
      });
      _startCountdown();
    }
    unawaited(initCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release the camera when backgrounded; re-init on resume if shooting.
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      // Re-engage the lock if the OS resurrected the Activity while locked —
      // initState wouldn't fire again, so a resumed screen could otherwise
      // expose staff chrome with the kid still holding the phone.
      if (_locked && mounted) {
        _kidMode.enter();
        _kidLockedRoute.pin(_pinnedRoute);
      }
      if (_run.current.mode == ActivityMode.shoot) {
        unawaited(initCamera());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Leave kid mode if we exit the screen still locked, so leaving never
    // strands the whole app in kid mode (AppShell would keep chrome stripped
    // on every staff screen). Cached notifiers — never `ref` in dispose.
    // exit()/pin(null) are idempotent, so this is safe even when already
    // unlocked. Guarded so a never-locked run is a no-op; covers both the
    // PopScope flag and the provider-write flag so neither path strands kid
    // mode.
    if (_locked || _lockEngaged) {
      _kidMode.exit();
      _kidLockedRoute.pin(null);
    }
    _staffTapReset?.cancel();
    _focusTimer?.cancel();
    _slideTimer?.cancel();
    _countdown?.cancel();
    _viewerPage?.dispose();
    _slidePage?.dispose();
    _filmstrip.dispose();
    disposeCamera();
    super.dispose();
  }

  /// Capability ranges for the new controller (zoom), read before the
  /// mixin publishes it.
  @override
  Future<void> onCameraReady(CameraController controller) async {
    _minZoom = await controller.getMinZoomLevel();
    _maxZoom = await controller.getMaxZoomLevel();
    _zoom = _minZoom;
  }

  // ── Kid lock ─────────────────────────────────────────────────────────

  /// Engage the opt-in lock ("Hand to the kids"). Enters kid mode + pins the
  /// route exactly as the reference kid screens do. The camera is untouched —
  /// it keeps running so the kid can shoot. Idempotent.
  ///
  /// Writing `kidModeProvider` (which AppShell watches) synchronously from a
  /// tap is fine — the tap is well outside the build phase. We defer through
  /// a microtask anyway to match the documented shape and to stay robust if
  /// this ever moves into a build-adjacent callback; the `mounted` guard
  /// covers a same-frame pop.
  void _engageKidLock() {
    if (_lockEngaged) return;
    _lockEngaged = true;
    // Resolve the route to pin BEFORE the microtask, while context is valid.
    // A timed turn pins the LIVE shell location (the picker's route the runner
    // was pushed over) so the redirect targets here, not the plain studio.
    _pinnedRoute = _resolvePinnedRoute();
    // `_locked` is already true in a timed turn (set in initState); setState
    // here covers the opt-in "Hand to the kids" path and is a harmless no-op
    // when already locked.
    if (!_locked) {
      setState(() => _locked = true);
    }
    _staffTapCount = 0;
    _exitDialogOpen = false;
    unawaited(HapticFeedback.mediumImpact());
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        try {
          _kidMode.enter();
          _kidLockedRoute.pin(_pinnedRoute);
        } on Object catch (e, st) {
          if (kDebugMode) {
            debugPrint('[photography] kid-lock enter failed: $e\n$st');
          }
        }
      }),
    );
  }

  /// The route the redirect should pin to. The plain studio (reached directly
  /// at `/activity/photo`) pins that constant. A timed turn is pushed
  /// imperatively over the picker, so its matchedLocation is the picker's
  /// (`/activity/photo-turns`) — pin THAT so the redirect doesn't bounce the
  /// stack to the plain studio. Reads the live location defensively; falls
  /// back to the constant if the router state can't be read.
  String _resolvePinnedRoute() {
    if (!widget.isTurn) return _lockedRoute;
    try {
      final path = GoRouterState.of(context).uri.path;
      return path.isEmpty ? _lockedRoute : path;
    } on Object catch (_) {
      // Defensive: if GoRouterState isn't available for any reason, fall back
      // to the picker route by name so the pin is at least plausible.
      return '/activity/photo-turns';
    }
  }

  /// Release the lock (staff unlocked via the corner gesture). Clears the
  /// pin BEFORE anything else so the router stops bouncing nav, exits kid
  /// mode (AppShell restores chrome), and flips the local flag so the
  /// runner's normal PopScope behaviour resumes. Idempotent.
  void _releaseKidLock() {
    if (!_locked && !_lockEngaged) return;
    _kidLockedRoute.pin(null);
    _kidMode.exit();
    _lockEngaged = false;
    if (mounted) setState(() => _locked = false);
  }

  /// Tapping the (now-locked) lock button can't unlock — that would defeat
  /// the lock. Point staff at the real exit instead of a dead no-op.
  void _hintStaffExit() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Locked. Staff: tap the top-left corner 5 times to exit.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Hidden staff-exit: count taps on the top-left corner; on the fifth
  /// within the window, open the PIN dialog. A correct PIN (or no PIN
  /// configured) releases the lock so the teacher reclaims the phone.
  Future<void> _onStaffCornerTap() async {
    _staffTapCount += 1;
    _staffTapReset?.cancel();
    if (_staffTapCount >= _staffTapTarget) {
      _staffTapCount = 0;
      _staffTapReset = null;
      // Re-entrancy guard: a kid hammering the corner while staff is in the
      // dialog must not stack a second dialog.
      if (_exitDialogOpen) return;
      _exitDialogOpen = true;
      try {
        final result = await showKidModeExitDialog(context, ref);
        if (!mounted) return;
        switch (result) {
          case KidModeExitResult.unlocked:
          case KidModeExitResult.noPinConfigured:
            _releaseKidLock();
            // In a timed turn, the corner-unlock is the staff "reclaim the
            // phone" gesture — whether the buzzer fired or staff cut it short.
            // Release the lock, then hand control back to the picker (mark this
            // child done + return to the roster) instead of stranding staff on
            // a now-unlocked camera. `_releaseKidLock` already cleared the pin,
            // so `_endTurn`'s pop won't fight the router redirect.
            if (widget.isTurn) {
              _endTurn();
            } else {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Unlocked. Press back to exit.')),
              );
            }
          case KidModeExitResult.cancelled:
            break;
        }
      } finally {
        _exitDialogOpen = false;
      }
      return;
    }
    _staffTapReset = Timer(_staffTapWindow, () {
      _staffTapCount = 0;
      _staffTapReset = null;
    });
  }

  // ── Timed-turn countdown ─────────────────────────────────────────────

  /// (Re)start the turn countdown. Cancels any prior timer first so two can
  /// never run at once. Each tick decrements `_secondsLeft`, guards on
  /// `mounted`, and at 0 cancels itself and raises the hard-stop. A no-op
  /// when this isn't a timed turn.
  void _startCountdown() {
    if (!widget.isTurn) return;
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _countdown = null;
        setState(() {
          _secondsLeft = 0;
          _timeUp = true;
        });
        // Close any open viewer/present so the hard-stop is the only thing on
        // screen — a kid shouldn't keep curating past the buzzer.
        if (_viewingIndex != null) _closeViewer();
        if (_presenting) _closePresentation();
        unawaited(HapticFeedback.heavyImpact());
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  /// `mm:ss` for the chrome timer. Clamps at 0 so a late tick can't render
  /// a negative.
  String _formatCountdown(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  /// The turn is over and staff have reclaimed the phone (corner-unlock after
  /// the buzzer). Hand control back to the picker, which marks this child done
  /// and returns to the roster. Falls back to a plain pop if no callback was
  /// wired (standalone turn).
  void _endTurn() {
    _countdown?.cancel();
    _countdown = null;
    final cb = widget.onTurnEnded;
    if (cb != null) {
      cb();
    } else if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
    // Hard-stop: once the turn's buzzer has fired, the shutter is dead. The
    // overlay also blocks the tap visually, but guard here too so a queued
    // gesture can't sneak a frame in after time.
    if (_timeUp) return;
    final c = cameraController;
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
      // Re-check the buzzer AFTER the (async) capture: a `takePicture()` that
      // was already in flight when time ran out must NOT land as a post-buzzer
      // shot. Drop the frame silently — the turn is over.
      if (_timeUp) return;
      // Snapshot the turn's child + block onto the shot NOW, so persistence
      // stamps the child who actually took it regardless of any later widget
      // change (the cross-child-leak guard).
      final newShot = _Shot(
        bytes,
        file: shot,
        aspectRatio: ar,
        capturedBySubjectId: widget.turnSubjectId,
        scheduleBlockId: widget.scheduleBlockId,
      );
      setState(() => _shots.add(newShot));
      // In a timed turn, EVERY shot files into the child's folder — persist it
      // immediately (stamped with capturedBySubjectId) so nothing the child
      // captures in their five minutes is lost, and the review can show their
      // full set. Favorites are chosen later, in the review. (In the plain
      // Photo Studio, persistence stays opt-in via the share heart.)
      if (widget.isTurn) {
        // A turn shot is a keeper by default + gets its stable attachment id.
        newShot
          ..shared = true
          ..attachmentId = const Uuid().v4();
        // TURN: hold the bytes LOCAL (selective sync) — they upload only once
        // the teacher hearts the shot in review. The row + per-child tags write
        // immediately so the folder + done-count work offline. (B1: this is the
        // ONLY path that defers; the plain-studio heart uploads immediately.)
        unawaited(_persistShot(newShot, deferUpload: true));
      }
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

  Future<void> _applyZoom(double target) async {
    final clamped = target.clamp(_minZoom, _maxZoom);
    if (clamped == _zoom) return;
    setState(() => _zoom = clamped);
    final c = cameraController;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setZoomLevel(clamped);
    } on Object catch (_) {}
  }

  Future<void> _focusAt(Offset local, Size size) async {
    final c = cameraController;
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
      // PLAIN STUDIO: sharing IS the curation, so upload NORMALLY — no
      // selective hold. A studio share's row gets `sort_order = max+1` (never
      // 0), so deferring it would strand the bytes forever (B1). The hold is
      // ONLY for timed-turn shots, which are hearted in a separate review.
      unawaited(_persistShot(shot, deferUpload: false));
    }
  }

  /// Upload one shared shot's bytes to the private person-photos bucket
  /// and write the attachment row. No PII in logs — errors go to
  /// FlutterError (gated/scrubbed there), never a raw print of the path.
  ///
  /// [deferUpload] is the selective-sync HOLD and MUST track which path called
  /// us (the B1 correctness fix):
  ///   • TIMED PER-CHILD TURN (`_shoot`, every shot) → `true`: the bytes stay
  ///     LOCAL and upload only once the teacher hearts the shot in review (the
  ///     attachment row's `sort_order == 0`, written by
  ///     `attachmentActions.reorder`). The row + tags still write immediately,
  ///     so the per-child folder + done-count work fully offline; only the
  ///     bytes wait. The teacher curates the 50 → keeps a few.
  ///   • PLAIN PHOTO STUDIO (`_toggleShared`, the gallery heart) → `false`: a
  ///     shared studio shot uploads NORMALLY, right away. Sharing IS the
  ///     curation, and the row's `sort_order` is `max+1` (never 0), so a
  ///     deferred entry would `wait` forever and never upload — exactly the
  ///     bug this parameter fixes.
  ///
  /// B5 (DOCUMENTED limitation): when `deferUpload == true` on WEB,
  /// `uploadOnly` has no on-device queue (no filesystem) and falls back to an
  /// IMMEDIATE upload — so a web teacher running turns uploads EVERY shot,
  /// uncurated, with no selective hold. Accepted because the photo-turns flow
  /// is inherently one-shared-phone-in-person (pass the phone child to child);
  /// it is not a web use case. No hard block this slice.
  Future<void> _persistShot(_Shot shot, {required bool deferUpload}) async {
    final attId = shot.attachmentId;
    if (attId == null) return;
    final service = ref.read(photoServiceProvider);
    final attachments = ref.read(attachmentActionsProvider);
    // The `pending:<id>` token `uploadOnly` returns when it defers bytes to the
    // offline queue. Captured so that if the row-create below throws, we drop
    // that just-enqueued entry instead of orphaning its bytes on disk (B2).
    // Stays null when the upload landed immediately (online, or the web
    // fallback) — there's nothing queued to clean up then.
    String? pendingToken;
    try {
      final url = await service.uploadOnly(
        entityKind: 'attachment',
        entityId: attId,
        picked: shot.file,
        deferUpload: deferUpload,
      );
      // Remember the queue id ONLY when bytes were actually deferred (token
      // shape `pending:<id>`); a real path means nothing was queued.
      if (url.startsWith('pending:')) pendingToken = url;
      await attachments.add(
        id: attId,
        entityKind: photoSessionEntity.kind,
        entityId: photoSessionEntity.id,
        url: url,
        caption: shot.reflection.trim().isEmpty ? null : shot.reflection.trim(),
        // Per-child turn tags (migration 20260621000001): stamp WHO shot it
        // (their progress folder, read by attachmentsCapturedByProvider) and
        // WHICH block it came from. Read from the SHOT (snapshotted at capture),
        // never `widget`, so an in-flight persist can't mis-stamp if the widget
        // is ever recycled. Null in the plain Photo Studio. This is the keystone
        // of the timed turns — every shot files into the child's folder.
        capturedBySubjectId: shot.capturedBySubjectId,
        scheduleBlockId: shot.scheduleBlockId,
      );
    } on Object catch (e, st) {
      // Roll back the de-dupe marker so a later re-share can retry the
      // upload rather than being silently skipped forever.
      shot.attachmentId = null;
      // B2: the deferred enqueue already wrote bytes to disk + a queue entry.
      // With the row-create now failed, that entry is orphaned (no row points
      // at it, and a re-share enqueues a FRESH copy), growing pending_uploads
      // until the orphan-sweep. Drop it explicitly. The token carries the
      // queue id; `remove` strips the `pending:` prefix itself.
      if (pendingToken != null) {
        unawaited(ref.read(photoUploadQueueProvider).remove(pendingToken));
      }
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'photography'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ONE effective PopScope, branched on lock state so there's exactly one
    // behaviour per state:
    //   • LOCKED   → canPop:false, back is fully blocked (the kid-lock wins);
    //                the snackbar tells the teacher how to get out. Overlay
    //                back is intentionally suppressed too — a kid can't
    //                back-out of the viewer/present either; the staff corner
    //                is the only way.
    //   • UNLOCKED → the runner's normal behaviour: back closes an open
    //                overlay first (viewer, then presentation), else exits.
    final canPop = !_locked && _viewingIndex == null && !_presenting;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_locked) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Hand the device back to a teacher to exit.'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        if (_viewingIndex != null) {
          _closeViewer();
        } else if (_presenting) {
          _closePresentation();
        }
      },
      child: EdgeScaffold(
        body: ColoredBox(
          color: Colors.black,
          // Conditional / runtime-swapped children → stable Keys so an
          // appearing/disappearing sibling (the lock cue + corner) can't shift
          // position-based Element matching and poison the viewer's
          // InlineEditableText input connection (CLAUDE.md interaction rule
          // #7 / "Stack children without keys").
          child: Stack(
            children: [
              Positioned.fill(
                key: const ValueKey('photo-runner-content'),
                child: _run.current.mode == ActivityMode.shoot
                    ? _shootView(context)
                    : (_presenting
                          ? _presentation(context)
                          : _galleryView(context)),
              ),
              if (_viewingIndex != null && _viewingIndex! < _shots.length)
                Positioned.fill(
                  key: const ValueKey('photo-runner-viewer'),
                  child: _viewer(context),
                ),
              // The turn's hard-stop. Covers the camera (opaque) so the kid
              // can't shoot once time's up; the only way forward is staff
              // reclaiming via the corner. Below the locked-chip + corner so
              // both stay reachable. A kid reads "give the phone to your
              // teacher"; staff read the 5-tap hint.
              if (_timeUp)
                const Positioned.fill(
                  key: ValueKey('photo-runner-times-up'),
                  child: _TimesUpOverlay(),
                ),
              // Visible "locked" cue — phase-independent (the top-bar lock
              // button only shows in the shoot view; gallery + present have no
              // top bar). Top-centre so the teacher reads the state from
              // across the room. Icon + word, never colour alone. IgnorePointer
              // so it can't steal the staff-corner tap or any control.
              if (_locked)
                const Positioned(
                  key: ValueKey('photo-runner-locked-chip'),
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(child: _LockedChip()),
                ),
              // Hidden staff-exit corner — only while locked. Top-left 56×56,
              // translucent so it never eats a real control but still
              // hit-tests the five taps. Sits ABOVE every overlay (and the
              // cue) so staff can always reach it (viewer/present included).
              if (_locked)
                Positioned(
                  key: const ValueKey('photo-runner-staff-corner'),
                  top: 0,
                  left: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () => unawaited(_onStaffCornerTap()),
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
    final c = cameraController;
    switch (camStatus) {
      case CamStatus.ready when c != null && c.value.isInitialized:
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
      case CamStatus.denied:
        return CamMessage(
          icon: Icons.no_photography_outlined,
          title: 'Camera access needed',
          message: 'Allow the camera so you can take photos.',
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
              Expanded(
                child: widget.isTurn
                    ? _TurnBanner(
                        name: widget.turnSubjectName ?? 'Their',
                        prompt: widget.prompt,
                        countdown: _formatCountdown(_secondsLeft),
                        urgent: _secondsLeft <= 30,
                      )
                    : _MissionBanner(prompt: widget.prompt),
              ),
              const SizedBox(width: 8),
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
              // Opt-in kid lock. Once locked, the button stays in the bar as
              // the visible "locked" cue (filled amber lock). A kid CAN tap it,
              // but it CANNOT unlock — instead it surfaces the staff-exit
              // guidance (no silent no-op, per the interaction rules). The
              // only real way out is the hidden staff 5-tap corner. The camera
              // keeps running regardless.
              //
              // Hidden in a timed turn: the lock auto-engages and the
              // `_LockedChip` already shows the state, so a manual toggle is
              // redundant noise on a child's locked turn.
              if (!widget.isTurn) ...[
                const SizedBox(width: 8),
                CamCapButton(
                  icon: _locked ? Icons.lock : Icons.lock_open_outlined,
                  active: _locked,
                  tooltip: _locked
                      ? 'Locked — staff exit only'
                      : 'Hand to the kids',
                  onTap: _locked ? _hintStaffExit : _engageKidLock,
                ),
              ],
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
                  // Left slot: a non-interactive shot count in a turn (balances
                  // the row); empty in the plain studio.
                  SizedBox(
                    width: 64,
                    child: widget.isTurn
                        ? Center(
                            child: Text(
                              '${_shots.length}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Center(
                      child: CamShutterButton(busy: _shooting, onTap: _shoot),
                    ),
                  ),
                  // Right slot: the kid-tappable "Done" ends the plain studio
                  // session. HIDDEN in a turn — a turn ends on the buzzer or a
                  // staff corner-unlock, never a kid tap, so a child can't cut
                  // their own time short or escape into the curate flow.
                  SizedBox(
                    width: 64,
                    child: widget.isTurn
                        ? null
                        : TextButton(
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
    disposeCamera();
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

/// The visible "kid lock is on" cue — a small pill, top-centre, shown across
/// every phase while locked. Icon + the word "Locked" (never colour alone,
/// per the no-color-only rule). White-on-dark hardcode is correct: this whole
/// screen is a raw camera/immersive canvas on the theme allowlist, and the
/// pill must read on top of a live camera feed or a bright photo.
class _LockedChip extends StatelessWidget {
  const _LockedChip();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.7),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Colors.amberAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  'Locked',
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

/// The timed-turn header — the child's name, a big live countdown, and the
/// mission, in one card the kid (and the room) read at a glance. White-on-dark
/// hardcode is correct: this is the raw camera canvas on the theme allowlist,
/// and it must read over a live feed. The countdown flips to a warm red in the
/// final 30 s so "wrap it up" reads without watching the digits.
class _TurnBanner extends StatelessWidget {
  const _TurnBanner({
    required this.name,
    required this.prompt,
    required this.countdown,
    required this.urgent,
  });

  final String name;
  final String prompt;
  final String countdown;
  final bool urgent;

  @override
  Widget build(BuildContext context) {
    final timerColor = urgent ? const Color(0xFFFF6B6B) : Colors.white;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 16, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '$name’s turn',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.timer_outlined, color: timerColor, size: 18),
              const SizedBox(width: 4),
              Text(
                countdown,
                style: TextStyle(
                  color: timerColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            prompt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

/// The turn's hard-stop overlay — a calm, opaque full-screen "Time's up" the
/// kid reads when the buzzer fires. It blocks the camera (no more shooting);
/// the only way forward is staff reclaiming the phone via the hidden corner.
/// Raw-canvas white-on-dark (theme allowlist). A second line tells staff how
/// to reclaim, so the screen is never a dead end.
class _TimesUpOverlay extends StatelessWidget {
  const _TimesUpOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // Opaque (not translucent) so the kid can't peek at the camera and keep
      // composing — the turn is genuinely over.
      color: const Color(0xFF101216),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.amberAccent.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    Icons.timer_off_outlined,
                    color: Colors.amberAccent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Time’s up!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Give the phone to your teacher.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Staff: tap the top-left corner 5 times to take the next turn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
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
