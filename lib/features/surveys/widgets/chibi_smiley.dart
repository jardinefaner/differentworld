// Canvas painting code reads more clearly with explicit `canvas.x()`
// calls interleaved with `canvas.save()` / `canvas.restore()` than
// with cascade chains. The lint flags every adjacent draw call here.
// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The three smileys the survey uses. Each is rendered from the same
/// 200×200 design grid the user's HTML mock uses, so the proportions
/// match what they sketched: an organic blob body in a stable
/// palette, dot/arc eyes, a kind-appropriate mouth, plus little
/// "personality" extras — tears on the sad one, sparkles on the happy.
///
/// Idle animations (bob, blink, breathe, tear-drop, sparkle) run off
/// a single per-widget [AnimationController] that loops every 10 s.
/// CustomPainter computes per-frame transforms from the controller's
/// 0..1 value, avoiding multiple controllers per smiley.
enum ChibiMood { disagree, kindOfAgree, agree }

extension ChibiMoodX on ChibiMood {
  String get label => switch (this) {
        ChibiMood.disagree => 'Disagree',
        ChibiMood.kindOfAgree => 'Kind of agree',
        ChibiMood.agree => 'Agree!',
      };

  /// Friendlier label for the practice questions ("Today, I am
  /// feeling …") where Disagree/Agree feels wrong.
  String get feelingLabel => switch (this) {
        ChibiMood.disagree => 'Not great',
        ChibiMood.kindOfAgree => 'Okay',
        ChibiMood.agree => 'Great!',
      };
}

class ChibiSmiley extends StatefulWidget {
  const ChibiSmiley({
    required this.mood,
    this.selected = false,
    this.dimmed = false,
    this.size = 140,
    super.key,
  });

  final ChibiMood mood;
  final bool selected;
  final bool dimmed;
  final double size;

  @override
  State<ChibiSmiley> createState() => _ChibiSmileyState();
}

class _ChibiSmileyState extends State<ChibiSmiley>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle;

  @override
  void initState() {
    super.initState();
    // Shared idle controller, one loop = 10s. Per-effect cycles
    // derive from this single source via modulo math in the painter.
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    unawaited(_idle.repeat());
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _paletteFor(widget.mood);
    final scale = widget.selected ? 1.08 : (widget.dimmed ? 0.94 : 1.0);
    final opacity = widget.dimmed ? 0.45 : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: opacity,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        scale: scale,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _idle,
            builder: (_, _) => CustomPaint(
              painter: _ChibiPainter(
                mood: widget.mood,
                palette: palette,
                selected: widget.selected,
                ringColor: theme.colorScheme.primary,
                t: _idle.value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChibiPalette {
  const _ChibiPalette({
    required this.fill,
    required this.shade,
    required this.ink,
    required this.blush,
  });
  final Color fill;
  final Color shade;
  final Color ink;
  final Color blush;
}

_ChibiPalette _paletteFor(ChibiMood mood) {
  // Palettes lifted directly from the user's HTML mock COLORS array.
  return switch (mood) {
    ChibiMood.disagree => const _ChibiPalette(
        fill: Color(0xFFEF6F63),
        shade: Color(0xFFC34A3E),
        ink: Color(0xFF2A2622),
        blush: Color(0xFFE8634A),
      ),
    ChibiMood.kindOfAgree => const _ChibiPalette(
        fill: Color(0xFFF6D469),
        shade: Color(0xFFC9A23A),
        ink: Color(0xFF2A2622),
        blush: Color(0xFFE8634A),
      ),
    ChibiMood.agree => const _ChibiPalette(
        fill: Color(0xFF8FC9A3),
        shade: Color(0xFF5E9A78),
        ink: Color(0xFF2A2622),
        blush: Color(0xFFE8634A),
      ),
  };
}

class _ChibiPainter extends CustomPainter {
  _ChibiPainter({
    required this.mood,
    required this.palette,
    required this.selected,
    required this.ringColor,
    required this.t,
  });

  final ChibiMood mood;
  final _ChibiPalette palette;
  final bool selected;
  final Color ringColor;

  /// Idle controller value [0..1).
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // The path data is authored in a 200×200 design grid (matches the
    // user's HTML mock). Scale to fit.
    canvas.save();
    final scale = size.width / 200;
    canvas.scale(scale, scale);

    // Idle bob: body moves up ~4px and rotates ±1° on a 3.6s cycle.
    final bobPhase = _wave(t, 3.6 / 10); // 0..1 over 3.6s
    final dy = -4 * _smoothStep(bobPhase);
    final rot = math.sin(bobPhase * 2 * math.pi) * (math.pi / 180);
    canvas.save();
    canvas.translate(100, 110); // pivot near the body center
    canvas.rotate(rot);
    canvas.translate(-100, -110 + dy);

    _drawBody(canvas);
    _drawHighlight(canvas);
    _drawEyes(canvas);
    if (mood != ChibiMood.disagree) _drawBlush(canvas);
    _drawMouth(canvas);
    if (mood == ChibiMood.disagree) _drawTears(canvas);

    canvas.restore();

    if (mood == ChibiMood.agree) _drawSparks(canvas);
    if (selected) _drawSelectionRing(canvas);

    canvas.restore();
  }

  // ---- Body ----

  /// Three subtly different blob silhouettes per mood, matching the
  /// "tall / circle / wide" feeling from the HTML mock so each mood
  /// reads even before the user sees color or features.
  void _drawBody(Canvas canvas) {
    final body = switch (mood) {
      ChibiMood.disagree => _pathTall(),
      ChibiMood.kindOfAgree => _pathCircle(),
      ChibiMood.agree => _pathWide(),
    };
    final fill = Paint()
      ..color = palette.fill
      ..isAntiAlias = true;
    final ink = Paint()
      ..color = palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas
      ..drawPath(body, fill)
      ..drawPath(body, ink);
  }

  /// Hand-drawn highlight stroke on the upper-left of the body — the
  /// same gesture the HTML mock uses to feel sketched, not vector-y.
  void _drawHighlight(Canvas canvas) {
    final highlight = Path()
      ..moveTo(54, 60)
      ..quadraticBezierTo(62, 48, 84, 46);
    final paint = Paint()
      ..color = palette.shade.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawPath(highlight, paint);
  }

  // 'tall' shape, ported from the HTML SHAPES catalog.
  Path _pathTall() => Path()
    ..moveTo(62, 30)
    ..quadraticBezierTo(100, 22, 138, 32)
    ..quadraticBezierTo(156, 50, 154, 100)
    ..quadraticBezierTo(156, 150, 134, 168)
    ..quadraticBezierTo(100, 176, 66, 166)
    ..quadraticBezierTo(44, 148, 46, 100)
    ..quadraticBezierTo(44, 50, 62, 30)
    ..close();

  // 'circle' shape from the HTML SHAPES catalog.
  Path _pathCircle() => Path()
    ..moveTo(100, 32)
    ..quadraticBezierTo(150, 34, 164, 78)
    ..quadraticBezierTo(174, 122, 144, 154)
    ..quadraticBezierTo(108, 178, 68, 160)
    ..quadraticBezierTo(32, 142, 32, 100)
    ..quadraticBezierTo(34, 56, 70, 38)
    ..quadraticBezierTo(84, 32, 100, 32)
    ..close();

  // 'wide' shape from the HTML SHAPES catalog.
  Path _pathWide() => Path()
    ..moveTo(30, 96)
    ..quadraticBezierTo(26, 60, 64, 46)
    ..quadraticBezierTo(104, 32, 144, 44)
    ..quadraticBezierTo(180, 56, 178, 100)
    ..quadraticBezierTo(176, 144, 144, 160)
    ..quadraticBezierTo(102, 174, 60, 160)
    ..quadraticBezierTo(30, 144, 30, 96)
    ..close();

  // ---- Eyes ----

  void _drawEyes(Canvas canvas) {
    // Idle blink: scaleY shrinks at 94-98% of a 5.2s cycle. Outside
    // that window the eyes are at scaleY=1.
    final blinkPhase = _wave(t, 5.2 / 10);
    final blinkActive = blinkPhase >= 0.94 && blinkPhase <= 0.98;
    final scaleY = blinkActive ? 0.08 : 1.0;

    canvas.save();
    final ink = Paint()
      ..color = palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final inkFill = Paint()
      ..color = palette.ink
      ..isAntiAlias = true;

    switch (mood) {
      case ChibiMood.disagree:
        // Sad arcs — "worried eyebrow" eyes. Curves upward.
        for (final cx in [76.0, 124.0]) {
          canvas.save();
          canvas.translate(cx, 92);
          canvas.scale(1, scaleY);
          final path = Path()
            ..moveTo(-10, 4)
            ..quadraticBezierTo(0, -6, 10, 4);
          canvas.drawPath(path, ink);
          canvas.restore();
        }
      case ChibiMood.kindOfAgree:
        // Dot eyes — neutral, calm.
        for (final cx in [76.0, 124.0]) {
          canvas.save();
          canvas.translate(cx, 94);
          canvas.scale(1, scaleY);
          canvas.drawCircle(Offset.zero, 3.8, inkFill);
          canvas.restore();
        }
      case ChibiMood.agree:
        // Squinty smile-arcs — the HTML's "Love it" eyes.
        for (final cx in [76.0, 124.0]) {
          canvas.save();
          canvas.translate(cx, 92);
          canvas.scale(1, scaleY);
          final path = Path()
            ..moveTo(-12, 4)
            ..quadraticBezierTo(0, -10, 12, 4);
          canvas.drawPath(path, ink);
          canvas.restore();
        }
    }
    canvas.restore();
  }

  // ---- Blush ----

  void _drawBlush(Canvas canvas) {
    // Blush pulses opacity + scale on a 4.2s cycle.
    final pulse = _wave(t, 4.2 / 10);
    final s = 1 + 0.08 * math.sin(pulse * 2 * math.pi);
    final alpha = 0.7 + 0.15 * math.sin(pulse * 2 * math.pi).abs();
    final paint = Paint()
      ..color = palette.blush.withValues(alpha: alpha)
      ..isAntiAlias = true;
    for (final cx in [62.0, 138.0]) {
      canvas.save();
      canvas.translate(cx, 120);
      canvas.scale(s, s);
      final rx = mood == ChibiMood.agree ? 11.0 : 10.0;
      final ry = mood == ChibiMood.agree ? 6.0 : 5.5;
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        paint,
      );
      canvas.restore();
    }
  }

  // ---- Mouth ----

  void _drawMouth(Canvas canvas) {
    final breathe = _wave(t, 3.6 / 10);
    final s = 1 + 0.04 * math.sin(breathe * 2 * math.pi);
    final ink = Paint()
      ..color = palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    canvas.save();
    canvas.translate(100, 130);
    canvas.scale(s, s);
    canvas.translate(-100, -130);

    switch (mood) {
      case ChibiMood.disagree:
        // Frown — downturned arc, control point above the endpoints.
        final path = Path()
          ..moveTo(80, 138)
          ..quadraticBezierTo(100, 124, 120, 138);
        canvas.drawPath(path, ink);
      case ChibiMood.kindOfAgree:
        // Flat line.
        final path = Path()
          ..moveTo(86, 132)
          ..lineTo(114, 132);
        canvas.drawPath(path, ink);
      case ChibiMood.agree:
        // Open D-smile (the HTML's "Love it" mouth).
        final mouth = Path()
          ..moveTo(78, 128)
          ..lineTo(122, 128)
          ..quadraticBezierTo(122, 152, 100, 152)
          ..quadraticBezierTo(78, 152, 78, 128)
          ..close();
        canvas
          ..drawPath(mouth, Paint()..color = palette.ink)
          ..drawPath(mouth, ink);
    }

    canvas.restore();
  }

  // ---- Tears (disagree only) ----

  void _drawTears(Canvas canvas) {
    // Two tears, staggered. Each tear drops 30px over a 2.6s cycle
    // and fades out at the end.
    _drawOneTear(canvas, 76, 102, phase: 0);
    _drawOneTear(canvas, 124, 102, phase: 0.45);
  }

  void _drawOneTear(
    Canvas canvas,
    double x,
    double startY, {
    required double phase,
  }) {
    const dur = 2.6 / 10;
    final raw = ((t / dur) + phase) % 1.0;
    final dy = raw * 30;
    final opacity = raw < 0.2
        ? raw * 5
        : raw > 0.8
            ? (1 - raw) * 5
            : 1.0;
    final paint = Paint()
      ..color = const Color(0xFF6FB3C4).withValues(alpha: opacity.clamp(0, 1))
      ..isAntiAlias = true;
    final path = Path()
      ..moveTo(x, startY + dy)
      ..quadraticBezierTo(x - 3, startY + dy + 6, x, startY + dy + 10)
      ..quadraticBezierTo(x + 3, startY + dy + 6, x, startY + dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  // ---- Sparkles (agree only) ----

  void _drawSparks(Canvas canvas) {
    // Three sparkles around the head — each on its own 2.4s phase
    // pulse, rotating slightly.
    _drawOneSpark(canvas, 28, 58, phase: 0, color: const Color(0xFFF4B14A));
    _drawOneSpark(canvas, 174, 52, phase: 0.33, color: const Color(0xFFE8634A));
    _drawOneSpark(canvas, 180, 112, phase: 0.66, color: const Color(0xFFF6D469));
  }

  void _drawOneSpark(
    Canvas canvas,
    double x,
    double y, {
    required double phase,
    required Color color,
  }) {
    const dur = 2.4 / 10;
    final raw = ((t / dur) + phase) % 1.0;
    // 0..1..0 pulse via sin: peak at the middle of the cycle.
    final pulse = math.sin(raw * math.pi);
    final s = 0.5 + 0.7 * pulse;
    final rot = pulse * (math.pi / 9); // up to ~20°
    final alpha = 0.3 + 0.7 * pulse;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    canvas.scale(s, s);

    // Four-point sparkle star.
    final star = Path()
      ..moveTo(0, -6)
      ..lineTo(1.5, -1.5)
      ..lineTo(6, 0)
      ..lineTo(1.5, 1.5)
      ..lineTo(0, 6)
      ..lineTo(-1.5, 1.5)
      ..lineTo(-6, 0)
      ..lineTo(-1.5, -1.5)
      ..close();
    canvas.drawPath(
      star,
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  // ---- Selection ring ----

  void _drawSelectionRing(Canvas canvas) {
    final ring = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..isAntiAlias = true;
    canvas.drawOval(
      Rect.fromCircle(center: const Offset(100, 105), radius: 92),
      ring,
    );
  }

  // ---- Helpers ----

  /// Wrap the master 0..1 controller into a per-effect 0..1 cycle.
  /// `dur` is the effect's duration as a fraction of the controller's
  /// total duration (so a 3.6s effect on a 10s controller has
  /// `dur = 0.36`).
  double _wave(double tValue, double dur) => (tValue / dur) % 1.0;

  /// Hill function: 0..1..0 over [0,1]. Used by `bob` for a smooth
  /// rise-and-return rather than a linear sawtooth.
  double _smoothStep(double phase) => math.sin(phase * math.pi);

  @override
  bool shouldRepaint(covariant _ChibiPainter old) =>
      old.t != t ||
      old.mood != mood ||
      old.selected != selected ||
      old.ringColor != ringColor;
}
