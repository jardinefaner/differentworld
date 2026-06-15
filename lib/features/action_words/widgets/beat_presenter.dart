import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/house_timer.dart';
import 'package:differentworld/features/action_words/present_timer.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/shared/platform/fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The app dark theme, computed once (not per `setState`/stepper rebuild).
final ThemeData _darkTheme = buildDarkTheme();

/// The one immersive **present surface** for any ordered run of [DayBeat]s —
/// the day's run of show (`/play-today`) and any single activity's story arc
/// (`/arc`) both render through this (docs/VISION.md "with present/cast… like a
/// prompt"). Full-screen, read-from-across-the-room, swipe / tap-zone / on-
/// screen controls to advance; the same surface a device can mirror/cast to a
/// projector.
///
/// This is the *single correct lifecycle*: cache the immersive notifier in
/// `initState` (never touch `ref` in `dispose`), defer the provider write out
/// of the build phase via a `mounted`-guarded microtask with the OS immersive
/// call locked inside it, restore `edgeToEdge` on `dispose`, and keep the
/// screen awake the whole time (a cast must not sleep). New present surfaces
/// compose this widget instead of re-deriving the lifecycle.
///
/// Controls (QoL for a teacher running a room): visible prev / next, a jump-
/// to-beat menu (so the teacher never hunts for where a beat lives), and a
/// cast countdown **timer** (the Timer primitive — time-bound by construction)
/// the whole room can see. Haptic tick on every advance.
class BeatPresenter extends ConsumerStatefulWidget {
  const BeatPresenter({
    required this.beats,
    required this.accent,
    this.emoji = '',
    this.initialBeat = 0,
    this.onBeatChanged,
    this.showGuidance = true,
    super.key,
  });

  /// Show the staff "your move" guidance card above the controls — the
  /// conductor's score (what to say / watch for / what's next), per beat.
  /// On for the day run + activity arc; a tour can pass false.
  final bool showGuidance;

  /// The ordered run. Rendered one beat per full-screen page.
  final List<DayBeat> beats;

  /// The room's colour — tints the top of the background gradient + captions.
  final Color accent;

  /// Optional hero glyph for `open` beats (the day run's world emoji).
  final String emoji;

  /// Where to start the run. The day run lands on the beat for the current
  /// phase (a mid-program open opens at the activity, not beat 1); the
  /// activity arc always starts at 0. Clamped to a valid index.
  final int initialBeat;

  /// Fired with the new beat index whenever the page changes. The day run
  /// uses it to remember where the teacher was, so re-opening resumes there
  /// instead of teleporting to the phase's beat; the arc leaves it null.
  final ValueChanged<int>? onBeatChanged;

  @override
  ConsumerState<BeatPresenter> createState() => _BeatPresenterState();
}

class _BeatPresenterState extends ConsumerState<BeatPresenter> {
  late final PageController _page;
  late final CastImmersive _immersive;
  int _index = 0;

  // The cast timer (Timer primitive). null = no timer; 0 = finished ("Time!").
  Timer? _ticker;
  int? _remaining;

  // Hands-free auto-advance: when on, the run plays itself (for an unattended
  // TV — the journey at a season opener, a child's growth arc at pickup). Loops
  // at the end. Default off; the teacher opts in.
  Timer? _autoTimer;
  bool _autoPlaying = false;
  static const _autoAdvanceInterval = Duration(seconds: 8);

  int get _count => widget.beats.length;

  @override
  void initState() {
    super.initState();
    // Cache the notifier (never touch ref in dispose) — the cast pattern.
    _immersive = ref.read(castImmersiveProvider.notifier);
    final initial = widget.beats.isEmpty
        ? 0
        : widget.initialBeat.clamp(0, widget.beats.length - 1);
    _index = initial;
    _page = PageController(initialPage: initial);
    // Defer the provider write out of the build phase (the chrome trap), and
    // guard on `mounted` so a fast pop can't strand the chrome hidden. Keep
    // the immersive OS call INSIDE the same microtask so the two stay locked.
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        _immersive.enter();
        unawaited(
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
        );
      }),
    );
    // A present/cast surface must not let the screen sleep mid-activity.
    unawaited(WakelockPlus.enable());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _autoTimer?.cancel();
    _immersive.exit();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    unawaited(WakelockPlus.disable());
    _page.dispose();
    super.dispose();
  }

  void _toggleAutoPlay() {
    if (!mounted) return;
    setState(() => _autoPlaying = !_autoPlaying);
    unawaited(HapticFeedback.selectionClick());
    if (_autoPlaying) {
      _scheduleAutoAdvance();
    } else {
      _autoTimer?.cancel();
      _autoTimer = null;
    }
  }

  void _scheduleAutoAdvance() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(_autoAdvanceInterval, (_) {
      if (!mounted || !_autoPlaying) return;
      // Loop at the end so an unattended showcase runs forever.
      if (_index >= _count - 1) {
        _jumpTo(0);
      } else {
        _go(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final beats = widget.beats;
    final accent = widget.accent;
    if (beats.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(accent.withValues(alpha: 0.45), Colors.black),
              Colors.black,
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              PageView.builder(
                // Stable keys: the timer pill is a conditional Stack child,
                // so every sibling needs a key or Flutter matches by position
                // and poisons Element identity when the pill appears (the
                // house rule — see CLAUDE.md "Stack children without keys").
                key: const ValueKey('bp-pageview'),
                controller: _page,
                itemCount: beats.length,
                onPageChanged: (i) {
                  if (!mounted) return;
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _index = i);
                  widget.onBeatChanged?.call(i);
                },
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 56,
                  ),
                  child: _BeatSlide(
                    beat: beats[i],
                    accent: accent,
                    emoji: widget.emoji,
                  ),
                ),
              ),
              // Tap zones: left third = back, right third = forward. Redundant
              // with the visible controls below, for quick advance anywhere.
              Positioned.fill(
                key: const ValueKey('bp-tapzones'),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        // Opaque, or a childless GestureDetector hit-tests
                        // nothing and the tap falls through to the PageView.
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _go(-1),
                      ),
                    ),
                    const Spacer(),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _go(1),
                      ),
                    ),
                  ],
                ),
              ),
              // Close — top-right.
              Positioned(
                key: const ValueKey('bp-close'),
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              // Fullscreen — top-left, WEB ONLY. Native already hides the
              // system bars via immersiveSticky; on web the browser chrome
              // stays unless the Fullscreen API is invoked from a tap. This is
              // the "view it fullscreen on the TV" control when casting from a
              // laptop tab.
              if (webFullscreenSupported)
                Positioned(
                  key: const ValueKey('bp-fullscreen'),
                  top: 8,
                  left: 8,
                  child: IconButton(
                    tooltip: 'Fullscreen',
                    icon: const Icon(Icons.fullscreen, color: Colors.white70),
                    onPressed: () => unawaited(toggleWebFullscreen()),
                  ),
                ),
              // The cast timer — top-centre, room-readable, tap to clear.
              if (_remaining != null)
                Positioned(
                  key: const ValueKey('bp-timer'),
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(child: _timerPill()),
                ),
              // Staff "your move" guidance — the conductor's score. Sits just
              // above the controls; ignores pointers so the tap-to-advance
              // zones still fire through it. (A future two-device cast keeps
              // it off the room screen entirely; for now it's bottom chrome.)
              if (widget.showGuidance &&
                  beatGuidance(beats[_index]).isNotEmpty)
                Positioned(
                  key: const ValueKey('bp-guidance'),
                  left: 8,
                  right: 8,
                  bottom: 58,
                  child: _GuidanceCard(
                    text: beatGuidance(beats[_index]),
                    nextLabel: _index < _count - 1
                        ? beatKindShortLabel(beats[_index + 1].kind)
                        : null,
                  ),
                ),
              // Control bar — timer · ‹ index/dots › · jump-to-beat.
              Positioned(
                key: const ValueKey('bp-controls'),
                left: 8,
                right: 8,
                bottom: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _autoPlayCtrl(),
                        const SizedBox(width: 4),
                        _ctrl(
                          Icons.timer_outlined,
                          'Set a timer',
                          () => unawaited(_pickTimer()),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ctrl(Icons.chevron_left, 'Previous', () => _go(-1)),
                        const SizedBox(width: 4),
                        _progress(),
                        const SizedBox(width: 4),
                        _ctrl(Icons.chevron_right, 'Next', () => _go(1)),
                      ],
                    ),
                    _ctrl(
                      Icons.list,
                      'Jump to a beat',
                      () => unawaited(_pickBeat()),
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

  // "3 / 11" + dots.
  Widget _progress() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${_index + 1} / ${widget.beats.length}',
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          letterSpacing: 1,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 6),
      // A FIXED-WIDTH track, not per-beat dots: one dot per beat overflowed
      // the control bar on a long run (the bar's middle slot is ~100 dp; 11+
      // beats × 13 dp blew 26 px past the edge on a Pixel — 2026-06-15). The
      // track scales to any beat count and the "i / N" text above carries the
      // exact position. White on the dark immersive stage (a raw canvas — see
      // THEME_ADHERENCE), matching the rest of these controls.
      SizedBox(
        width: 72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: widget.beats.isEmpty
                ? 0
                : (_index + 1) / widget.beats.length,
            minHeight: 4,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    ],
  );

  Widget _ctrl(IconData icon, String tip, VoidCallback onTap) => IconButton(
    tooltip: tip,
    icon: Icon(icon, color: Colors.white),
    onPressed: onTap,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white.withValues(alpha: 0.12),
    ),
  );

  /// Play/pause hands-free auto-advance. Tinted with the room accent while
  /// playing so "it's running itself" reads from across the room.
  Widget _autoPlayCtrl() => IconButton(
    tooltip: _autoPlaying ? 'Pause auto-advance' : 'Auto-advance (hands-free)',
    icon: Icon(
      _autoPlaying ? Icons.pause : Icons.play_arrow,
      color: Colors.white,
    ),
    onPressed: _toggleAutoPlay,
    style: IconButton.styleFrom(
      backgroundColor: _autoPlaying
          ? widget.accent.withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.12),
    ),
  );

  Widget _timerPill() {
    final done = _remaining == 0;
    return GestureDetector(
      onTap: _clearTimer,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: (done ? Colors.amber.shade700 : Colors.black).withValues(
            alpha: 0.6,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.notifications_active : Icons.timer_outlined,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              done ? 'Time!' : mmss(_remaining!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(int delta) {
    if (!mounted) return;
    final next = (_index + delta).clamp(0, _count - 1);
    if (next == _index) return;
    unawaited(
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      ),
    );
  }

  void _jumpTo(int i) {
    if (!mounted) return;
    final next = i.clamp(0, _count - 1);
    if (next == _index) return;
    unawaited(
      _page.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      ),
    );
  }

  // ── Timer ────────────────────────────────────────────────────────────

  void _startTimerSeconds(int seconds) {
    if (seconds <= 0) return;
    _ticker?.cancel();
    setState(() => _remaining = seconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer t) {
    if (!mounted) {
      t.cancel();
      return;
    }
    final r = _remaining;
    if (r == null || r <= 0) {
      t.cancel();
      return;
    }
    setState(() => _remaining = r - 1);
    if (_remaining == 0) {
      t.cancel();
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _clearTimer() {
    _ticker?.cancel();
    if (mounted) setState(() => _remaining = null);
  }

  Future<void> _pickTimer() async {
    final beats = widget.beats;
    final suggested = (_index >= 0 && _index < beats.length)
        ? beats[_index].suggestedSeconds
        : 0;
    final remembered = ref.read(presentTimerProvider).value ?? const <int>[];
    // Three concerns, sourced here so the sheet stays presentational: the
    // per-beat suggestion (curriculum), the house presets (program policy),
    // and the remembered customs (this device).
    final housePresets = ref.read(houseTimerPresetsProvider);
    final result = await showModalBottomSheet<({int seconds, bool custom})>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      builder: (ctx) => _TimerSheet(
        suggestedSeconds: suggested,
        presetMinutes: housePresets,
        remembered: remembered,
        running: _remaining != null,
      ),
    );
    if (result == null || !mounted) return;
    if (result.seconds <= 0) {
      _clearTimer();
      return;
    }
    _startTimerSeconds(result.seconds);
    // Only an explicitly-dialed custom value is worth remembering — presets
    // and the per-beat suggestion are already one tap away.
    if (result.custom) {
      unawaited(
        ref.read(presentTimerProvider.notifier).remember(result.seconds),
      );
    }
  }

  Future<void> _pickBeat() async {
    final beats = widget.beats;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (var j = 0; j < beats.length; j++)
              ListTile(
                leading: Text(
                  '${j + 1}',
                  style: const TextStyle(color: Colors.white38, fontSize: 16),
                ),
                title: Text(
                  beats[j].label.isEmpty ? beats[j].big : beats[j].label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: j == _index ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                selected: j == _index,
                selectedTileColor: Colors.white10,
                onTap: () => Navigator.pop(ctx, j),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _jumpTo(picked);
  }
}

/// Renders one [DayBeat] as a full-screen, read-from-across-the-room slide.
class _BeatSlide extends StatelessWidget {
  const _BeatSlide({required this.beat, required this.accent, this.emoji = ''});

  final DayBeat beat;
  final Color accent;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final caption = Text(
      beat.label.toUpperCase(),
      semanticsLabel: beat.label,
      textAlign: TextAlign.center,
      style: TextStyle(
        // AA-safe on the dark slide — a pale accent tint, not the raw accent
        // (teal/blue only hit ~3:1 on near-black).
        color: AppColors.readableOnDark(accent),
        fontSize: 20,
        letterSpacing: 4,
        fontWeight: FontWeight.w600,
      ),
    );

    // A keepsake photo — the child's actual moment, full-bleed, with the
    // caption over a bottom scrim. (Growth arc; docs/VISION.md "drawing
    // becomes a film".) Signed URL resolved by the screen; graceful on a slow
    // / failed load so the reel never stalls on a dark void.
    if (beat.kind == DayBeatKind.photo) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (beat.imageUrl.isNotEmpty)
            // The app's signed-URL + cached photo widget (the attachment
            // carries a Storage PATH, not a usable URL — PersonPhotoNetwork
            // mints + caches the signed URL). Covers by default.
            PersonPhotoNetwork(
              urlOrPath: beat.imageUrl,
              placeholderBuilder: (_) => const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(28, 72, 28, 44),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  caption,
                  if (beat.big.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _headline(beat.big, 30),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    // The world hero.
    if (beat.kind == DayBeatKind.open) {
      return _centered([
        Text(
          beat.emoji.isNotEmpty ? beat.emoji : emoji,
          style: const TextStyle(fontSize: 130),
        ),
        const SizedBox(height: 22),
        caption,
        const SizedBox(height: 10),
        _headline(beat.big, 54),
        if (beat.sub.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            beat.sub,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 24,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ]);
    }

    // List beats — verbs, the bridge zoom-out, the activity menu.
    if (beat.lines.isNotEmpty) {
      final big = beat.kind == DayBeatKind.verbs;
      return _centered([
        caption,
        const SizedBox(height: 28),
        for (final line in beat.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Text(
              big ? line.toUpperCase() : line,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: big ? 38 : 22,
                fontWeight: big ? FontWeight.w700 : FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
      ]);
    }

    // Big-text beats — question, rule, watch, play, name, ask, close.
    // Long bodies (play it / name it) get a smaller size so they fit.
    final size = switch (beat.kind) {
      DayBeatKind.play || DayBeatKind.name => 32.0,
      DayBeatKind.watch || DayBeatKind.rule => 38.0,
      _ => 44.0,
    };
    return _centered([
      caption,
      const SizedBox(height: 24),
      _headline(beat.big, size),
      if (beat.sub.isNotEmpty) ...[
        const SizedBox(height: 20),
        Text(
          beat.sub,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 24),
        ),
      ],
    ]);
  }

  Widget _centered(List<Widget> children) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: children,
  );

  Widget _headline(String text, double size) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      color: Colors.white,
      fontSize: size,
      fontWeight: FontWeight.w700,
      height: 1.2,
    ),
  );
}

/// The "set a timer" sheet. Leads with the beat's *suggested* length (one
/// tap), offers quick presets + the teacher's remembered customs, and a
/// stepper to dial any length. Pops `(seconds, custom)` — `custom` true only
/// for a dialed value, so the present surface knows what to remember.
class _TimerSheet extends StatefulWidget {
  const _TimerSheet({
    required this.suggestedSeconds,
    required this.presetMinutes,
    required this.remembered,
    required this.running,
  });

  final int suggestedSeconds;

  /// The program's house presets (minutes) — sourced by the caller from
  /// [houseTimerPresetsProvider]; the sheet just renders them.
  final List<int> presetMinutes;
  final List<int> remembered;
  final bool running;

  @override
  State<_TimerSheet> createState() => _TimerSheetState();
}

class _TimerSheetState extends State<_TimerSheet> {
  late int _customMin = widget.suggestedSeconds > 0
      ? (widget.suggestedSeconds / 60).round().clamp(1, 60)
      : 5;

  static String _label(int seconds) =>
      seconds % 60 == 0 ? '${seconds ~/ 60} min' : mmss(seconds);

  void _pop(int seconds, {required bool custom}) =>
      Navigator.pop(context, (seconds: seconds, custom: custom));

  @override
  Widget build(BuildContext context) {
    // Quick chips: the program's house presets, then any remembered customs
    // that aren't already a preset (deduped, whole-minute).
    final presetMins = widget.presetMinutes;
    final quickMins = <int>[
      ...presetMins,
      for (final s in widget.remembered)
        if (s % 60 == 0 && !presetMins.contains(s ~/ 60)) s ~/ 60,
    ];

    return Theme(
      data: _darkTheme,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Set a timer',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (widget.suggestedSeconds > 0) ...[
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        _pop(widget.suggestedSeconds, custom: false),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(
                      'Suggested for this beat · ${_label(widget.suggestedSeconds)}',
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in quickMins)
                      ActionChip(
                        label: Text('$m min'),
                        onPressed: () => _pop(m * 60, custom: false),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 4),
                const Text(
                  'Custom',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Less',
                      iconSize: 30,
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _customMin > 1
                          ? () => setState(() => _customMin--)
                          : null,
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        '$_customMin min',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'More',
                      iconSize: 30,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: _customMin < 60
                          ? () => setState(() => _customMin++)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => _pop(_customMin * 60, custom: true),
                  child: Text('Start $_customMin min'),
                ),
                if (widget.running) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => _pop(0, custom: false),
                    child: const Text('Stop timer'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The staff's "your move" card — the conductor's-score line for the current
/// beat, shown on the phone above the controls. `IgnorePointer` so the
/// tap-to-advance zones beneath it still fire.
class _GuidanceCard extends StatelessWidget {
  const _GuidanceCard({required this.text, this.nextLabel});

  final String text;
  final String? nextLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_outlined, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'YOUR MOVE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (nextLabel != null) ...[
                      const Spacer(),
                      Text(
                        'Next: $nextLabel',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
