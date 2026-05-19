// Canvas painting code reads more clearly with explicit `canvas.x()`
// calls interleaved with `canvas.save()` / `canvas.restore()` than
// with cascade chains. The lint flags every adjacent draw call here.
// ignore_for_file: cascade_invocations

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shape + color identity that stays constant within a single survey
/// question. Eight variants total — `ChibiVariant.forQuestionIndex(i)`
/// rotates them deterministically across the survey so each question
/// has a unique mascot the kid can orient on ("the orange round one
/// — that's the one about reading"), but every answer option within
/// that question shares the look. Only the [ChibiExpression] differs.
enum ChibiVariant {
  /// Tall, warm coral. A reaching-up posture.
  tallCoral,

  /// Tall, sky blue. The same posture, calmer hue.
  tallSky,

  /// Round, golden yellow. The "classic" friendly blob.
  circleGold,

  /// Round, grass green. The "classic" but mellow.
  circleGrass,

  /// Wide, lavender. Squashed proportions, soft purple.
  wideLavender,

  /// Wide, warm orange. The "happy chair" feeling.
  wideOrange,

  /// Egg (narrow top, wide bottom), buttercream. Cozy.
  eggCream,

  /// Egg, teal. Cool counterweight to the warm cream egg.
  eggTeal;

  /// Deterministic rotation across questions. Q0 → tallCoral, Q1 →
  /// tallSky, …, Q8 → tallCoral again. Even if a template grows past
  /// 8 questions, the kid still sees a recognizable rhythm.
  static ChibiVariant forQuestionIndex(int i) {
    const list = ChibiVariant.values;
    final n = i.abs() % list.length;
    return list[n];
  }
}

/// How the chibi's face reads. Five expressions, three of them map
/// to the agree3 answer triplet (no / maybe / yes); the other two
/// are reserved for non-agree3 use (excited closeout, dreamy /
/// "thinking" mood).
enum ChibiExpression {
  /// Worried eyebrow-eyes + frown + a slow tear. The "No / Disagree"
  /// answer face — agree3 value 0.
  sad,

  /// Slightly off-center eyes + a small squiggle mouth. The "Maybe /
  /// Kind of agree" answer face — agree3 value 1.
  unsure,

  /// Dot eyes + flat line mouth. Neutral, not reserved for any
  /// answer slot — useful for multiselect option mascots that
  /// shouldn't pre-bias the kid toward yes or no.
  neutral,

  /// Squinty smile-arc eyes + open D-smile + sparkles. The "Yes /
  /// Agree!" answer face — agree3 value 2.
  happy,

  /// Bigger D-smile, brighter sparkles, slight bounce. The closeout
  /// celebration face.
  excited;

  /// Map an agree3 answer (0/1/2) to the matching expression.
  static ChibiExpression forAgree3(int value) => switch (value) {
        0 => ChibiExpression.sad,
        1 => ChibiExpression.unsure,
        2 => ChibiExpression.happy,
        _ => ChibiExpression.neutral,
      };

  /// "No / Disagree / Sad" labels for the agree3 triplet.
  static String agree3Label(int value, {bool practice = false}) {
    if (practice) {
      return switch (value) {
        0 => 'Not great',
        1 => 'Okay',
        2 => 'Great!',
        _ => '',
      };
    }
    return switch (value) {
      0 => 'No',
      1 => 'Maybe',
      2 => 'Yes',
      _ => '',
    };
  }
}

/// The chibi mascot. Identity is `variant` (shape + palette);
/// face is `expression` (eyes + mouth + decorations).
///
/// Idle animations (bob, blink, breathe, tear-drop, sparkle) loop off
/// a single per-widget [AnimationController]. When the parent
/// passes `selected = true` the smiley scales up, pulses brighter,
/// and emits a particle burst — see `_SelectionBurst`. The burst is
/// a sibling widget so a quick re-tap doesn't fight the painter for
/// frame budget.
class ChibiSmiley extends StatefulWidget {
  const ChibiSmiley({
    required this.variant,
    required this.expression,
    this.selected = false,
    this.dimmed = false,
    this.tapping = false,
    this.size = 140,
    super.key,
  });

  final ChibiVariant variant;
  final ChibiExpression expression;
  final bool selected;
  final bool dimmed;

  /// True for ~200ms after a tap fires — the parent flips it on,
  /// the smiley does a squash-and-stretch, then the parent flips
  /// it off. Independent of `selected` so the animation runs every
  /// tap, not just the first.
  final bool tapping;

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
    final palette = _paletteFor(widget.variant);

    // Squash-and-stretch on tap: scale down to 0.86 then bounce up
    // past 1 to 1.12, then settle. The selected steady-state is
    // 1.08. AnimatedScale with easeOutBack handles the bounce.
    final scale = widget.tapping
        ? 1.12
        : widget.selected
            ? 1.08
            : widget.dimmed
                ? 0.92
                : 1.0;
    final opacity = widget.dimmed ? 0.45 : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: opacity,
      child: AnimatedScale(
        duration: Duration(
          milliseconds: widget.tapping ? 180 : 220,
        ),
        curve: Curves.easeOutBack,
        scale: scale,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _idle,
            builder: (_, _) => CustomPaint(
              painter: _ChibiPainter(
                variant: widget.variant,
                expression: widget.expression,
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

// ---------------------------------------------------------------------------
// Palettes + shapes per variant.
// ---------------------------------------------------------------------------

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

const _ink = Color(0xFF2A2622);
const _commonBlush = Color(0xFFE8634A);

_ChibiPalette _paletteFor(ChibiVariant v) {
  return switch (v) {
    ChibiVariant.tallCoral => const _ChibiPalette(
        fill: Color(0xFFEF6F63),
        shade: Color(0xFFC34A3E),
        ink: _ink,
        blush: _commonBlush,
      ),
    ChibiVariant.tallSky => const _ChibiPalette(
        fill: Color(0xFF7EB7E0),
        shade: Color(0xFF4F8AB5),
        ink: _ink,
        blush: _commonBlush,
      ),
    ChibiVariant.circleGold => const _ChibiPalette(
        fill: Color(0xFFF6D469),
        shade: Color(0xFFC9A23A),
        ink: _ink,
        blush: _commonBlush,
      ),
    ChibiVariant.circleGrass => const _ChibiPalette(
        fill: Color(0xFF8FC9A3),
        shade: Color(0xFF5E9A78),
        ink: _ink,
        blush: _commonBlush,
      ),
    ChibiVariant.wideLavender => const _ChibiPalette(
        fill: Color(0xFFBDA8E0),
        shade: Color(0xFF8E76BB),
        ink: _ink,
        blush: _commonBlush,
      ),
    ChibiVariant.wideOrange => const _ChibiPalette(
        fill: Color(0xFFF4A05B),
        shade: Color(0xFFCC7733),
        ink: _ink,
        blush: _commonBlush,
      ),
    ChibiVariant.eggCream => const _ChibiPalette(
        fill: Color(0xFFF7E3B1),
        shade: Color(0xFFCAA866),
        ink: _ink,
        blush: _commonBlush,
      ),
    ChibiVariant.eggTeal => const _ChibiPalette(
        fill: Color(0xFF7BC4C4),
        shade: Color(0xFF4F9494),
        ink: _ink,
        blush: _commonBlush,
      ),
  };
}

enum _BodyShape { tall, circle, wide, egg }

_BodyShape _shapeFor(ChibiVariant v) => switch (v) {
      ChibiVariant.tallCoral || ChibiVariant.tallSky => _BodyShape.tall,
      ChibiVariant.circleGold || ChibiVariant.circleGrass => _BodyShape.circle,
      ChibiVariant.wideLavender || ChibiVariant.wideOrange => _BodyShape.wide,
      ChibiVariant.eggCream || ChibiVariant.eggTeal => _BodyShape.egg,
    };

// ---------------------------------------------------------------------------
// Painter — everything procedurally drawn so the only assets we ship
// are the path constants below.
// ---------------------------------------------------------------------------

class _ChibiPainter extends CustomPainter {
  _ChibiPainter({
    required this.variant,
    required this.expression,
    required this.palette,
    required this.selected,
    required this.ringColor,
    required this.t,
  });

  final ChibiVariant variant;
  final ChibiExpression expression;
  final _ChibiPalette palette;
  final bool selected;
  final Color ringColor;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = size.width / 200;
    canvas.scale(scale, scale);

    // Bob: body floats up ~4px and rotates ±1° on a 3.6s cycle.
    final bobPhase = _wave(t, 3.6 / 10);
    final dy = -4 * _smoothStep(bobPhase);
    final rot = math.sin(bobPhase * 2 * math.pi) * (math.pi / 180);
    canvas.save();
    canvas.translate(100, 110);
    canvas.rotate(rot);
    canvas.translate(-100, -110 + dy);

    _drawBody(canvas);
    _drawHighlight(canvas);
    _drawEyes(canvas);
    if (expression == ChibiExpression.happy ||
        expression == ChibiExpression.excited ||
        expression == ChibiExpression.unsure) {
      _drawBlush(canvas);
    }
    _drawMouth(canvas);
    if (expression == ChibiExpression.sad) _drawTears(canvas);

    canvas.restore();

    if (expression == ChibiExpression.happy ||
        expression == ChibiExpression.excited) {
      _drawSparks(canvas);
    }
    if (selected) _drawSelectionRing(canvas);

    canvas.restore();
  }

  // ---- Body ----

  void _drawBody(Canvas canvas) {
    final body = switch (_shapeFor(variant)) {
      _BodyShape.tall => _pathTall(),
      _BodyShape.circle => _pathCircle(),
      _BodyShape.wide => _pathWide(),
      _BodyShape.egg => _pathEgg(),
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

  // Body silhouettes — ported from the user's HTML SHAPES catalog
  // and extended with one more 'egg' shape for the 4th variant.

  Path _pathTall() => Path()
    ..moveTo(62, 30)
    ..quadraticBezierTo(100, 22, 138, 32)
    ..quadraticBezierTo(156, 50, 154, 100)
    ..quadraticBezierTo(156, 150, 134, 168)
    ..quadraticBezierTo(100, 176, 66, 166)
    ..quadraticBezierTo(44, 148, 46, 100)
    ..quadraticBezierTo(44, 50, 62, 30)
    ..close();

  Path _pathCircle() => Path()
    ..moveTo(100, 32)
    ..quadraticBezierTo(150, 34, 164, 78)
    ..quadraticBezierTo(174, 122, 144, 154)
    ..quadraticBezierTo(108, 178, 68, 160)
    ..quadraticBezierTo(32, 142, 32, 100)
    ..quadraticBezierTo(34, 56, 70, 38)
    ..quadraticBezierTo(84, 32, 100, 32)
    ..close();

  Path _pathWide() => Path()
    ..moveTo(30, 96)
    ..quadraticBezierTo(26, 60, 64, 46)
    ..quadraticBezierTo(104, 32, 144, 44)
    ..quadraticBezierTo(180, 56, 178, 100)
    ..quadraticBezierTo(176, 144, 144, 160)
    ..quadraticBezierTo(102, 174, 60, 160)
    ..quadraticBezierTo(30, 144, 30, 96)
    ..close();

  /// Egg: narrow top, broad bottom. Friendly, "settled" posture.
  Path _pathEgg() => Path()
    ..moveTo(100, 26)
    ..quadraticBezierTo(140, 32, 152, 86)
    ..quadraticBezierTo(166, 136, 138, 166)
    ..quadraticBezierTo(102, 182, 64, 166)
    ..quadraticBezierTo(36, 138, 50, 88)
    ..quadraticBezierTo(62, 32, 100, 26)
    ..close();

  // ---- Eyes ----

  void _drawEyes(Canvas canvas) {
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

    switch (expression) {
      case ChibiExpression.sad:
        // Worried "/\" arcs — eyebrows-ish.
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
      case ChibiExpression.unsure:
        // One dot, one off-center half-arc — quizzical.
        canvas.save();
        canvas.translate(76, 94);
        canvas.scale(1, scaleY);
        canvas.drawCircle(Offset.zero, 3.6, inkFill);
        canvas.restore();
        canvas.save();
        canvas.translate(124, 92);
        canvas.scale(1, scaleY);
        final path = Path()
          ..moveTo(-9, 2)
          ..quadraticBezierTo(0, -4, 9, 4);
        canvas.drawPath(path, ink);
        canvas.restore();
      case ChibiExpression.neutral:
        // Two dots — calm, doesn't telegraph an answer.
        for (final cx in [76.0, 124.0]) {
          canvas.save();
          canvas.translate(cx, 94);
          canvas.scale(1, scaleY);
          canvas.drawCircle(Offset.zero, 3.8, inkFill);
          canvas.restore();
        }
      case ChibiExpression.happy:
        // Squinty smile arcs.
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
      case ChibiExpression.excited:
        // Star eyes — sparkly highlight + ink ring.
        for (final cx in [76.0, 124.0]) {
          canvas.save();
          canvas.translate(cx, 92);
          canvas.scale(1, scaleY);
          canvas.drawCircle(Offset.zero, 5, inkFill);
          canvas.drawCircle(
            const Offset(-1.5, -1.5),
            1.4,
            Paint()
              ..color = const Color(0xFFFFFFFF)
              ..isAntiAlias = true,
          );
          canvas.restore();
        }
    }
    canvas.restore();
  }

  // ---- Blush ----

  void _drawBlush(Canvas canvas) {
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
      final rx = expression == ChibiExpression.happy ||
              expression == ChibiExpression.excited
          ? 11.0
          : 10.0;
      final ry = expression == ChibiExpression.happy ||
              expression == ChibiExpression.excited
          ? 6.0
          : 5.5;
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

    switch (expression) {
      case ChibiExpression.sad:
        final path = Path()
          ..moveTo(80, 138)
          ..quadraticBezierTo(100, 124, 120, 138);
        canvas.drawPath(path, ink);
      case ChibiExpression.unsure:
        // Tiny squiggle — left dip, right rise.
        final path = Path()
          ..moveTo(82, 134)
          ..quadraticBezierTo(92, 142, 100, 134)
          ..quadraticBezierTo(108, 126, 118, 134);
        canvas.drawPath(path, ink);
      case ChibiExpression.neutral:
        final path = Path()
          ..moveTo(86, 132)
          ..lineTo(114, 132);
        canvas.drawPath(path, ink);
      case ChibiExpression.happy:
        final mouth = Path()
          ..moveTo(78, 128)
          ..lineTo(122, 128)
          ..quadraticBezierTo(122, 152, 100, 152)
          ..quadraticBezierTo(78, 152, 78, 128)
          ..close();
        canvas
          ..drawPath(mouth, Paint()..color = palette.ink)
          ..drawPath(mouth, ink);
      case ChibiExpression.excited:
        // Big open smile — wider than happy, taller too.
        final mouth = Path()
          ..moveTo(74, 126)
          ..lineTo(126, 126)
          ..quadraticBezierTo(126, 156, 100, 156)
          ..quadraticBezierTo(74, 156, 74, 126)
          ..close();
        canvas
          ..drawPath(mouth, Paint()..color = palette.ink)
          ..drawPath(mouth, ink);
        // Tongue — tiny blush-colored arc inside.
        canvas.drawCircle(
          const Offset(100, 150),
          4,
          Paint()
            ..color = palette.blush
            ..isAntiAlias = true,
        );
    }

    canvas.restore();
  }

  // ---- Tears (sad only) ----

  void _drawTears(Canvas canvas) {
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

  // ---- Sparkles (happy + excited) ----

  void _drawSparks(Canvas canvas) {
    final extra = expression == ChibiExpression.excited;
    _drawOneSpark(canvas, 28, 58, phase: 0, color: const Color(0xFFF4B14A));
    _drawOneSpark(canvas, 174, 52, phase: 0.33, color: const Color(0xFFE8634A));
    _drawOneSpark(canvas, 180, 112, phase: 0.66, color: const Color(0xFFF6D469));
    if (extra) {
      // Two more for the excited variant — feels louder + busier.
      _drawOneSpark(canvas, 20, 130, phase: 0.15, color: const Color(0xFF8FC9A3));
      _drawOneSpark(canvas, 170, 170, phase: 0.5, color: const Color(0xFFBDA8E0));
    }
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
    final pulse = math.sin(raw * math.pi);
    final s = 0.5 + 0.7 * pulse;
    final rot = pulse * (math.pi / 9);
    final alpha = 0.3 + 0.7 * pulse;

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    canvas.scale(s, s);

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

  double _wave(double tValue, double dur) => (tValue / dur) % 1.0;

  double _smoothStep(double phase) => math.sin(phase * math.pi);

  @override
  bool shouldRepaint(covariant _ChibiPainter old) =>
      old.t != t ||
      old.variant != variant ||
      old.expression != expression ||
      old.selected != selected ||
      old.ringColor != ringColor;
}
