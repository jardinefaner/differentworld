import 'dart:async';
import 'dart:math';

import 'package:differentworld/features/games/game_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// **The moment a round ends, felt.** A burst of particles in the game's
/// accent over whatever stage is underneath, once, when `done` flips from
/// false to true — and a heavy tap in the host's hand at the same instant.
///
/// Deliberately ONE beat, not a fanfare: ~900 ms, a few dozen flecks in the
/// accent, warm paper and antique gold, falling under a little gravity and
/// fading out. Every game gets it from the scaffold with no per-game code,
/// which is the same principle as the wrap beat — the ending is a framework
/// moment, so the eleventh game somebody adds celebrates like the first.
///
/// Respects [GameMotion]: with motion off (OS reduce-motion, or the
/// Preferences switch) nothing is drawn, and the haptic still fires on the
/// phone because a buzz is not motion.
class CelebrationLayer extends StatefulWidget {
  const CelebrationLayer({
    required this.done,
    required this.accent,
    required this.child,
    super.key,
  });

  /// The round's done flag — the burst plays on the false → true edge.
  final bool done;

  /// The game's accent, which colours most of the flecks.
  final Color accent;

  final Widget child;

  @override
  State<CelebrationLayer> createState() => _CelebrationLayerState();
}

class _CelebrationLayerState extends State<CelebrationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  List<_Fleck> _flecks = const [];

  @override
  void initState() {
    super.initState();
    // Mounting ONTO a finished round (a cast receiver joining late, a plate)
    // is not an ending happening — no burst.
  }

  @override
  void didUpdateWidget(CelebrationLayer old) {
    super.didUpdateWidget(old);
    if (!old.done && widget.done) _celebrate();
  }

  void _celebrate() {
    if (GameMotion.hapticsOf(context)) {
      unawaited(HapticFeedback.heavyImpact());
    }
    if (!GameMotion.of(context)) return;
    final r = Random();
    _flecks = [for (var i = 0; i < 42; i++) _Fleck.random(r, widget.accent)];
    _burst
      ..stop()
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _burst,
            builder: (context, _) => _burst.isAnimating
                ? CustomPaint(
                    key: const ValueKey('celebration-burst'),
                    painter: _BurstPainter(_flecks, _burst.value),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    ],
  );
}

class _Fleck {
  const _Fleck({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
    required this.origin,
  });

  factory _Fleck.random(Random r, Color accent) {
    // Three colours, so the burst reads as the GAME's rather than generic:
    // its accent, warm paper, and the book's antique gold (BRAND.md law 3).
    const paper = Color(0xFFF4F1EA); // raw-canvas: a burst over the stage
    const gold = Color(0xFFC79A3E); // raw-canvas: a burst over the stage
    final pick = r.nextDouble();
    return _Fleck(
      // Mostly upward, a little sideways — a toss, not an explosion.
      angle: -pi / 2 + (r.nextDouble() - 0.5) * pi * 0.9,
      speed: 0.45 + r.nextDouble() * 0.55,
      size: 4 + r.nextDouble() * 6,
      color: pick < 0.55 ? accent : (pick < 0.8 ? paper : gold),
      spin: (r.nextDouble() - 0.5) * 6,
      origin: Offset(0.3 + r.nextDouble() * 0.4, 0.55),
    );
  }

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double spin;

  /// Where it starts, as a fraction of the stage — a band across the middle.
  final Offset origin;
}

class _BurstPainter extends CustomPainter {
  const _BurstPainter(this.flecks, this.t);

  final List<_Fleck> flecks;

  /// 0..1 through the burst.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (flecks.isEmpty) return;
    final reach = size.shortestSide * 0.55;
    final fade = (1 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
    final paint = Paint();
    for (final f in flecks) {
      // Ease-out on the throw, gravity on the fall.
      final d = Curves.easeOutCubic.transform(t) * f.speed * reach;
      final gravity = t * t * reach * 0.6;
      final x = size.width * f.origin.dx + cos(f.angle) * d;
      final y = size.height * f.origin.dy + sin(f.angle) * d + gravity;
      paint.color = f.color.withValues(alpha: fade);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(f.spin * t)
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: f.size,
              height: f.size * 0.6,
            ),
            const Radius.circular(1.5),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.flecks != flecks;
}
