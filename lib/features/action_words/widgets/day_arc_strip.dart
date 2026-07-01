import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The day's energy arc — each beat plotted by its energy value, drawn as a
/// line so the run-of-show's *shape* (gather → rise → peak → wind-down → close)
/// is visible at a glance (docs/VISION.md "the order is an arc"). A glance, not
/// a control — it doesn't respond to taps; it just shows the day's shape above
/// the deck.
class DayArcStrip extends StatelessWidget {
  const DayArcStrip({required this.energies, required this.accent, super.key});

  /// Each beat / block's energy 0..1, in order — the curve's y-values.
  final List<double> energies;

  /// The accent — the dots' colour (content-driven, like the deck tiles).
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // An arc needs at least two points to read as a shape.
    if (energies.length < 2) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: "The day's energy arc across ${energies.length} blocks",
      child: SizedBox(
        height: 64,
        width: double.infinity,
        child: CustomPaint(
          painter: _ArcPainter(
            energies: [for (final e in energies) e.clamp(0.0, 1.0)],
            accent: accent,
            line: scheme.onSurfaceVariant,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

/// A one-line "why this block sits HERE in the day" for each position in the
/// arc — the middle-UI "explain the arc" (docs/VISION.md "anticipation earns
/// trust when it can show its reasoning"). Pure, derived from the energy series
/// alone: the open, the close, local peaks/troughs, and whether energy is
/// rising / falling / holding. Returns one line per input energy, aligned.
List<String> dayArcNarrative(List<double> energies) {
  final n = energies.length;
  if (n == 0) return const [];
  if (n == 1) return const ['The whole day.'];
  final out = <String>[];
  for (var i = 0; i < n; i++) {
    final e = energies[i];
    if (i == 0) {
      out.add('Opening — gather and settle in.');
      continue;
    }
    if (i == n - 1) {
      out.add('Closing — wind down for the handoff home.');
      continue;
    }
    final prev = energies[i - 1];
    final next = energies[i + 1];
    if (e >= prev && e >= next && e >= 0.7) {
      out.add("The high point — they've warmed up; spend the energy here.");
    } else if (e <= prev && e <= next && e <= 0.35) {
      out.add('A calm dip — a breather between the busier blocks.');
    } else if (e > prev + 0.02) {
      out.add('Building energy toward the peak.');
    } else if (e < prev - 0.02) {
      out.add('Easing down from the peak.');
    } else {
      out.add('Holding a steady middle.');
    }
  }
  return out;
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.energies,
    required this.accent,
    required this.line,
    required this.textDirection,
  });

  final List<double> energies;
  final Color accent;
  final Color line;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    const topPad = 16.0;
    const botPad = 18.0; // room for the open / close labels
    const sidePad = 12.0;
    final n = energies.length;
    final usableW = size.width - sidePad * 2;
    final usableH = size.height - topPad - botPad;
    double xAt(int i) =>
        sidePad + (n == 1 ? usableW / 2 : usableW * i / (n - 1));
    double yAt(double e) => topPad + (1 - e) * usableH;

    final points = [
      for (var i = 0; i < n; i++) Offset(xAt(i), yAt(energies[i])),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < n; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = line.withValues(alpha: 0.45),
    );

    final dot = Paint()..color = accent;
    for (final p in points) {
      canvas.drawCircle(p, 3, dot);
    }

    _label(canvas, 'open', Offset(sidePad, size.height - 11), line, false);
    _label(
      canvas,
      'close',
      Offset(size.width - sidePad, size.height - 11),
      line,
      true,
    );
  }

  void _label(Canvas c, String s, Offset at, Color color, bool rightAlign) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
      ),
      textDirection: textDirection,
    )..layout();
    tp.paint(c, Offset(rightAlign ? at.dx - tp.width : at.dx, at.dy));
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      !listEquals(old.energies, energies) ||
      old.accent != accent ||
      old.line != line;
}
