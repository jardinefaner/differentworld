import 'dart:async';

import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one immersive **present surface** for any ordered run of [DayBeat]s —
/// the day's run of show (`/play-today`) and any single activity's story arc
/// (`/arc`) both render through this (docs/VISION.md "with present/cast… like a
/// prompt"). Full-screen, read-from-across-the-room, swipe or tap-zone to
/// advance; the same surface a device can mirror/cast to a projector.
///
/// This is the *single correct lifecycle*: cache the immersive notifier in
/// `initState` (never touch `ref` in `dispose`), defer the provider write out
/// of the build phase via a `mounted`-guarded microtask with the OS immersive
/// call locked inside it, and restore `edgeToEdge` on `dispose`. New present
/// surfaces compose this widget instead of re-deriving the lifecycle — there
/// used to be two copies and they drifted.
class BeatPresenter extends ConsumerStatefulWidget {
  const BeatPresenter({
    required this.beats,
    required this.accent,
    this.emoji = '',
    super.key,
  });

  /// The ordered run. Rendered one beat per full-screen page.
  final List<DayBeat> beats;

  /// The room's colour — tints the top of the background gradient + captions.
  final Color accent;

  /// Optional hero glyph for `open` beats (the day run's world emoji).
  final String emoji;

  @override
  ConsumerState<BeatPresenter> createState() => _BeatPresenterState();
}

class _BeatPresenterState extends ConsumerState<BeatPresenter> {
  final _page = PageController();
  late final CastImmersive _immersive;
  int _index = 0;

  int get _count => widget.beats.length;

  @override
  void initState() {
    super.initState();
    // Cache the notifier (never touch ref in dispose) — the cast pattern.
    _immersive = ref.read(castImmersiveProvider.notifier);
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
  }

  @override
  void dispose() {
    _immersive.exit();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    _page.dispose();
    super.dispose();
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
                controller: _page,
                itemCount: beats.length,
                onPageChanged: (i) {
                  if (mounted) setState(() => _index = i);
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
              // Tap zones: left third = back, right third = forward.
              Positioned.fill(
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
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              // Progress: "3 / 11" + dots.
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    Text(
                      '${_index + 1} / ${beats.length}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < beats.length; i++)
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _index
                                  ? Colors.white
                                  : Colors.white24,
                            ),
                          ),
                      ],
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
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color.alphaBlend(accent.withValues(alpha: 0.9), Colors.white70),
        fontSize: 20,
        letterSpacing: 4,
        fontWeight: FontWeight.w600,
      ),
    );

    // The world hero.
    if (beat.kind == DayBeatKind.open) {
      return _centered([
        Text(emoji, style: const TextStyle(fontSize: 130)),
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
