import 'dart:async';

import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/play-today` — **the day, on rails.** One ordered, full-screen run of show
/// for the live room: the world, its verbs + rule, Watch → Do, the Big
/// Thinking move (play → name → bridge → question), the activity, then the
/// closing handoff — assembled from *this week × this room* (docs/VISION.md
/// "The day, on rails"). The teacher just advances it; no hunting across
/// screens. Goes fully immersive so it reads as the room's screen, and is the
/// same present surface the device can mirror/cast to a projector.
class DayRunScreen extends ConsumerStatefulWidget {
  const DayRunScreen({super.key});

  @override
  ConsumerState<DayRunScreen> createState() => _DayRunScreenState();
}

class _DayRunScreenState extends ConsumerState<DayRunScreen> {
  final _page = PageController();
  late final CastImmersive _immersive;
  int _index = 0;
  int _count = 1;

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
    final world = ref.watch(currentWorldProvider);
    if (world == null) {
      // No live world (journey not set up) — nothing to run.
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No world is live yet',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set the journey start date to play the day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final weekThinking = ref.watch(thisWeekThinkingProvider);
    final beats = buildDayRun(
      world: world,
      rules: rulesForWorld(world.id),
      thinking: weekThinking.isEmpty ? null : weekThinking.first,
    );
    _count = beats.length;
    final accent = world.color;

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
                  child: _RunSlide(
                    beat: beats[i],
                    accent: accent,
                    emoji: world.emoji,
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
class _RunSlide extends StatelessWidget {
  const _RunSlide({required this.beat, required this.accent, this.emoji = ''});

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
