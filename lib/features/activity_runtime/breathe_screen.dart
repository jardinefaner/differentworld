import 'dart:async';

import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';

/// `/activity/breathe` — Mindful Minute. The calm counterpart to the
/// energizing games: a slow breathing circle the whole room follows
/// together. Box-ish breathing (in 4 · hold 1 · out 4). No content, no
/// typing, no score — just a reset. Tap anywhere to start / pause; the back
/// arrow exits (immersive, no kid-lock).
///
/// Respects reduced-motion (MediaQuery.disableAnimations): the scaling is
/// dropped for a static guide so the screen never forces motion on a user
/// who turned it off.
class BreatheScreen extends StatefulWidget {
  const BreatheScreen({super.key});

  @override
  State<BreatheScreen> createState() => _BreatheScreenState();
}

class _BreatheScreenState extends State<BreatheScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  // Phase boundaries on the 0..1 cycle: inhale (4) · hold (1) · exhale (4).
  static const double _inhaleEnd = 4 / 9;
  static const double _holdEnd = 5 / 9;

  // Scale endpoints (typed double so the Tweens infer double, not num).
  static const double _minScale = 0.45;
  static const double _maxScale = 1; // peak — a full breath in

  bool _running = false;
  int _breaths = 0;
  double _prev = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..addListener(_onTick);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: _minScale,
          end: _maxScale,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4,
      ),
      TweenSequenceItem(tween: ConstantTween(_maxScale), weight: 1),
      TweenSequenceItem(
        tween: Tween(
          begin: _maxScale,
          end: _minScale,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 4,
      ),
    ]).animate(_controller);
  }

  void _onTick() {
    // Detect the wrap (value drops ~1 → ~0) = one full breath completed.
    if (_controller.value < _prev - 0.5) {
      setState(() => _breaths++);
    }
    _prev = _controller.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      if (_running) {
        _controller.stop();
      } else {
        unawaited(_controller.repeat());
      }
      _running = !_running;
    });
  }

  String _phase(double v) {
    if (v < _inhaleEnd) return 'Breathe in…';
    if (v < _holdEnd) return 'Hold';
    return 'Breathe out…';
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return EdgeScaffold(
      body: GestureDetector(
        onTap: reduceMotion ? null : _toggle,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF12343B), Color(0xFF1B5159)],
            ),
          ),
          child: SafeArea(
            child: reduceMotion ? _staticGuide(context) : _animated(context),
          ),
        ),
      ),
    );
  }

  Widget _animated(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Spacer(),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                children: [
                  SizedBox(
                    height: 260,
                    width: 260,
                    child: Center(
                      child: Transform.scale(
                        scale: _scale.value,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.tealAccent.withValues(alpha: 0.18),
                            border: Border.all(
                              color: Colors.tealAccent.withValues(alpha: 0.55),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    _running ? _phase(_controller.value) : 'Tap to begin',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _running
                ? '$_breaths ${_breaths == 1 ? 'breath' : 'breaths'} · tap to pause'
                : 'Follow the circle — in, hold, out',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // Reduced-motion: a calm static guide, no scaling, no auto-cycling.
  Widget _staticGuide(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.tealAccent.withValues(alpha: 0.18),
              border: Border.all(
                color: Colors.tealAccent.withValues(alpha: 0.55),
                width: 2,
              ),
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            'Breathe in… hold… breathe out…',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Slow and steady, together.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
