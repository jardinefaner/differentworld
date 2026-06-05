import 'dart:async';
import 'dart:math' as math;

import 'package:differentworld/features/speak/speak_palette.dart';
import 'package:flutter/material.dart';

/// The stage's ambience: a slow, breathing gradient in the voice's [palette], a
/// vignette for depth, and a whisper of film grain — so the field reads as an
/// editorial space, not flat black. Nothing distracting: the gradient drifts
/// over ~18s; the grain is static (painted once, cached).
class LivingBackground extends StatefulWidget {
  const LivingBackground({
    required this.palette,
    required this.child,
    this.animate = true,
    super.key,
  });

  final SpeakPalette palette;
  final Widget child;

  /// Drift only while it's worth it — paused while the audio is paused / done
  /// so we don't repaint a gradient every frame for a still stage (battery).
  final bool animate;

  @override
  State<LivingBackground> createState() => _LivingBackgroundState();
}

class _LivingBackgroundState extends State<LivingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) unawaited(_drift.repeat(reverse: true));
  }

  @override
  void didUpdateWidget(LivingBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate == oldWidget.animate) return;
    if (widget.animate) {
      unawaited(_drift.repeat(reverse: true));
    } else {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _drift,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_drift.value);
        // Drift the gradient's poles slowly so the light seems to shift.
        final begin = Alignment.lerp(
          const Alignment(-0.7, -1),
          const Alignment(0.6, -0.7),
          t,
        )!;
        final end = Alignment.lerp(
          const Alignment(0.7, 1),
          const Alignment(-0.6, 0.9),
          t,
        )!;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [widget.palette.bgTop, widget.palette.bgBottom],
            ),
          ),
          child: child,
        );
      },
      // Static subtree — doesn't rebuild per drift frame.
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Vignette — darken the corners for editorial depth.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.15,
                colors: [Colors.transparent, Color(0x66000000)],
                stops: [0.55, 1],
              ),
            ),
          ),
          // Faint film grain.
          const RepaintBoundary(
            child: CustomPaint(painter: _GrainPainter(), size: Size.infinite),
          ),
          widget.child,
        ],
      ),
    );
  }
}

/// A whisper of static grain — deterministic (seeded) so it never shimmers,
/// painted once and cached by the [RepaintBoundary] above it.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rnd = math.Random(7);
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.02);
    final count = (size.width * size.height / 220).clamp(0, 5000).toInt();
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.6,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GrainPainter oldDelegate) => false;
}
