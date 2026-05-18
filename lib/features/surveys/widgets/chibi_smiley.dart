import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The three smileys the survey uses for an agree/disagree question.
///
/// Mapped to the survey's three-point scale:
///   disagree     → frown + sad-arc eyes, coral body
///   kindOfAgree  → flat mouth + dot eyes, yellow body
///   agree        → upturned smile + dot eyes, green body
///
/// The HTML mock the user shared has 5 expressions and 8 shape/color
/// rigs; v1 keeps the 3 we need with stable palette so kids learn the
/// mapping ("red = no, green = yes") without per-question variance.
enum ChibiMood { disagree, kindOfAgree, agree }

extension ChibiMoodX on ChibiMood {
  String get label => switch (this) {
        ChibiMood.disagree => 'Disagree',
        ChibiMood.kindOfAgree => 'Kind of agree',
        ChibiMood.agree => 'Agree!',
      };

  /// Short label used on practice questions where the agreement
  /// framing is awkward ("Today, I am feeling — disagree"? no).
  String get feelingLabel => switch (this) {
        ChibiMood.disagree => 'Not great',
        ChibiMood.kindOfAgree => 'Okay',
        ChibiMood.agree => 'Great!',
      };
}

/// One tappable smiley face. Renders the chibi figure at the
/// requested size (default 120dp) with body+eyes+mouth in stable
/// palette per [mood]. When [selected], scales up and pops a thin
/// ring; when [dimmed], drops opacity so the un-selected siblings
/// recede.
class ChibiSmiley extends StatelessWidget {
  const ChibiSmiley({
    required this.mood,
    this.selected = false,
    this.dimmed = false,
    this.size = 120,
    super.key,
  });

  final ChibiMood mood;
  final bool selected;
  final bool dimmed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _paletteFor(mood);
    final scale = selected ? 1.08 : (dimmed ? 0.94 : 1);
    final opacity = dimmed ? 0.4 : 1.0;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: opacity,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        scale: scale.toDouble(),
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _ChibiPainter(
              mood: mood,
              palette: palette,
              selected: selected,
              ringColor: theme.colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChibiPalette {
  const _ChibiPalette({required this.fill, required this.shade, required this.ink});
  final Color fill;
  final Color shade;
  final Color ink;
}

_ChibiPalette _paletteFor(ChibiMood mood) {
  switch (mood) {
    case ChibiMood.disagree:
      return const _ChibiPalette(
        fill: Color(0xFFEF6F63),
        shade: Color(0xFFC34A3E),
        ink: Color(0xFF2A2622),
      );
    case ChibiMood.kindOfAgree:
      return const _ChibiPalette(
        fill: Color(0xFFF6D469),
        shade: Color(0xFFC9A23A),
        ink: Color(0xFF2A2622),
      );
    case ChibiMood.agree:
      return const _ChibiPalette(
        fill: Color(0xFF8FC9A3),
        shade: Color(0xFF5E9A78),
        ink: Color(0xFF2A2622),
      );
  }
}

class _ChibiPainter extends CustomPainter {
  _ChibiPainter({
    required this.mood,
    required this.palette,
    required this.selected,
    required this.ringColor,
  });

  final ChibiMood mood;
  final _ChibiPalette palette;
  final bool selected;
  final Color ringColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Body — a soft squircle (rounded "blob"). Slightly off-vertical
    // to give it a hand-drawn lean; the math is `r * (1 + tiny noise
    // per quadrant)` simulated by tweaking the two ovals.
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy + h * 0.02),
      width: w * 0.86,
      height: h * 0.86,
    );
    final bodyPaint = Paint()
      ..color = palette.fill
      ..isAntiAlias = true;
    final inkPaint = Paint()
      ..color = palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final shadePaint = Paint()
      ..color = palette.shade.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.014
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final body = _buildBodyPath(bodyRect, mood);
    canvas
      ..drawPath(body, bodyPaint)
      ..drawPath(body, inkPaint);

    // Subtle highlight stroke (top-left curve) — the "hand-drawn shade"
    // from the HTML mock.
    final highlight = Path()
      ..moveTo(bodyRect.left + w * 0.14, bodyRect.top + h * 0.20)
      ..quadraticBezierTo(
        bodyRect.left + w * 0.06,
        bodyRect.top + h * 0.40,
        bodyRect.left + w * 0.10,
        bodyRect.top + h * 0.55,
      );
    canvas.drawPath(highlight, shadePaint);

    // Eyes — sad arcs / dots / dots (same dots for kindOf + agree).
    final eyeY = cy - h * 0.07;
    final eyeOff = w * 0.20;
    _drawEyes(canvas, w, eyeY, eyeOff, inkPaint, mood);

    // Cheeks for kindOf / agree (a little blush warms them up).
    if (mood != ChibiMood.disagree) {
      final blushPaint = Paint()
        ..color = const Color(0xFFE8634A).withValues(alpha: 0.55)
        ..isAntiAlias = true;
      canvas
        ..drawOval(
          Rect.fromCenter(
            center: Offset(cx - w * 0.28, cy + h * 0.14),
            width: w * 0.13,
            height: w * 0.07,
          ),
          blushPaint,
        )
        ..drawOval(
          Rect.fromCenter(
            center: Offset(cx + w * 0.28, cy + h * 0.14),
            width: w * 0.13,
            height: w * 0.07,
          ),
          blushPaint,
        );
    }

    // Mouth.
    _drawMouth(canvas, w, h, inkPaint, palette, mood);

    // Tears on the disagree face — a tiny touch, lots of personality.
    if (mood == ChibiMood.disagree) {
      final tearPaint = Paint()
        ..color = const Color(0xFF6FB3C4)
        ..isAntiAlias = true;
      _drawTear(canvas, Offset(cx - eyeOff, eyeY + h * 0.06), w, tearPaint);
      _drawTear(canvas, Offset(cx + eyeOff, eyeY + h * 0.06), w, tearPaint);
    }

    // Selection ring — drawn outside the body so it doesn't fight the
    // face. Soft, just a hint.
    if (selected) {
      final ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04
        ..isAntiAlias = true;
      final ringRect = bodyRect.inflate(w * 0.04);
      canvas.drawOval(ringRect, ringPaint);
    }
  }

  Path _buildBodyPath(Rect r, ChibiMood mood) {
    // Three subtly different body shapes so the moods feel distinct
    // even without color: a slightly droopier blob for sad, a balanced
    // squircle for meh, a rounder/wider one for happy.
    final cx = r.center.dx;
    final cy = r.center.dy;
    final hw = r.width / 2;
    final hh = r.height / 2;
    final droop = switch (mood) {
      ChibiMood.disagree => 0.10,
      ChibiMood.kindOfAgree => 0.0,
      ChibiMood.agree => -0.04,
    };
    final widen = switch (mood) {
      ChibiMood.disagree => -0.02,
      ChibiMood.kindOfAgree => 0.0,
      ChibiMood.agree => 0.04,
    };

    // 8-point squircle approximation — cubic-Bezier corners.
    final left = cx - hw * (1 + widen);
    final right = cx + hw * (1 + widen);
    final top = cy - hh * (1 - droop);
    final bottom = cy + hh * (1 + droop);
    final cornerX = hw * 0.55;
    final cornerY = hh * 0.55;

    return Path()
      ..moveTo(left, cy)
      ..cubicTo(
        left, top + cornerY,
        cx - cornerX, top,
        cx, top,
      )
      ..cubicTo(
        cx + cornerX, top,
        right, top + cornerY,
        right, cy,
      )
      ..cubicTo(
        right, bottom - cornerY,
        cx + cornerX, bottom,
        cx, bottom,
      )
      ..cubicTo(
        cx - cornerX, bottom,
        left, bottom - cornerY,
        left, cy,
      )
      ..close();
  }

  void _drawEyes(
    Canvas canvas,
    double w,
    double y,
    double offset,
    Paint ink,
    ChibiMood mood,
  ) {
    final cx = w / 2;
    final leftCenter = Offset(cx - offset, y);
    final rightCenter = Offset(cx + offset, y);

    switch (mood) {
      case ChibiMood.disagree:
        // Sad upside-down arcs — eyes furrowed in concern.
        final arc = w * 0.06;
        final path = Path()
          ..moveTo(leftCenter.dx - arc, y + arc * 0.4)
          ..quadraticBezierTo(
            leftCenter.dx,
            y - arc * 0.6,
            leftCenter.dx + arc,
            y + arc * 0.4,
          )
          ..moveTo(rightCenter.dx - arc, y + arc * 0.4)
          ..quadraticBezierTo(
            rightCenter.dx,
            y - arc * 0.6,
            rightCenter.dx + arc,
            y + arc * 0.4,
          );
        canvas.drawPath(path, ink);
      case ChibiMood.kindOfAgree:
      case ChibiMood.agree:
        // Dot eyes — friendly + neutral; same for meh and happy
        // so the smile carries the difference.
        final dot = Paint()
          ..color = palette.ink
          ..style = PaintingStyle.fill
          ..isAntiAlias = true;
        canvas
          ..drawCircle(leftCenter, w * 0.030, dot)
          ..drawCircle(rightCenter, w * 0.030, dot);
    }
  }

  void _drawMouth(
    Canvas canvas,
    double w,
    double h,
    Paint ink,
    _ChibiPalette palette,
    ChibiMood mood,
  ) {
    final cx = w / 2;
    final my = h * 0.66;

    switch (mood) {
      case ChibiMood.disagree:
        // Downturned arc (a small frown).
        final width = w * 0.18;
        final path = Path()
          ..moveTo(cx - width, my + h * 0.02)
          ..quadraticBezierTo(cx, my - h * 0.04, cx + width, my + h * 0.02);
        canvas.drawPath(path, ink);
      case ChibiMood.kindOfAgree:
        // Flat line.
        final width = w * 0.16;
        final path = Path()
          ..moveTo(cx - width, my)
          ..lineTo(cx + width, my);
        canvas.drawPath(path, ink);
      case ChibiMood.agree:
        // Open smile — quadratic with subtle inner shade so it reads
        // as joy at a glance.
        final width = w * 0.20;
        final mouthRect = Rect.fromCenter(
          center: Offset(cx, my + h * 0.02),
          width: width * 2,
          height: h * 0.08,
        );
        canvas
          ..drawArc(mouthRect, 0, math.pi, true, Paint()..color = palette.ink)
          ..drawArc(mouthRect, 0, math.pi, false, ink);
    }
  }

  void _drawTear(Canvas canvas, Offset start, double w, Paint paint) {
    final tearW = w * 0.025;
    final tearH = w * 0.05;
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(
        start.dx - tearW,
        start.dy + tearH / 2,
        start.dx,
        start.dy + tearH,
      )
      ..quadraticBezierTo(
        start.dx + tearW,
        start.dy + tearH / 2,
        start.dx,
        start.dy,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ChibiPainter old) =>
      old.mood != mood ||
      old.selected != selected ||
      old.ringColor != ringColor;
}
