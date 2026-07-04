import 'package:flutter/material.dart';

/// The Different World brand colours, fixed (not theme roles): the teal field
/// and the gold rising sun. Mirrors `_seed` / `AppColors.dark.gold` so the
/// mark matches the app's primary + world-accent.
const Color kBrandTeal = Color(0xFF2A9D8F);
const Color kBrandGold = Color(0xFFE6C079);

/// Paints the **Horizon** mark — a gold sun rising over a horizon (a different
/// world dawning). The single source of truth for the shape, shared by the
/// in-app [HorizonMark] widget AND the icon/splash generator
/// (`tool/render_brand_assets.dart`), so the launcher icon can never drift
/// from what the app draws.
///
/// Geometry is the 60-unit design space from the brand sheet, scaled into a
/// centered square of side `size.shortestSide * markScale`. [field] (when set)
/// fills the whole canvas first — the icon variant uses the teal field; the
/// adaptive-foreground / in-context variants pass null for transparency.
void paintHorizon(
  Canvas canvas,
  Size size, {
  Color? field,
  Color ink = Colors.white,
  Color sun = kBrandGold,
  double markScale = 0.62,
}) {
  if (field != null) {
    canvas.drawRect(Offset.zero & size, Paint()..color = field);
  }
  final s = size.shortestSide;
  final side = s * markScale;
  final dx = (size.width - side) / 2;
  final dy = (size.height - side) / 2;
  double x(double u) => dx + u / 60 * side;
  double y(double u) => dy + u / 60 * side;
  double len(double u) => u / 60 * side;

  // The rising sun — a gold disc clipped to ABOVE the horizon line, so only
  // a cresting semicircle shows.
  canvas
    ..save()
    ..clipRect(Rect.fromLTRB(dx, dy, dx + side, y(38.2)))
    ..drawCircle(
      Offset(x(30), y(38)),
      len(11),
      Paint()
        ..color = sun
        ..isAntiAlias = true,
    )
    ..restore();

  final rays = Paint()
    ..color = sun
    ..strokeWidth = len(2.2)
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  final line = Paint()
    ..color = ink
    ..strokeWidth = len(2.5)
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  // Three rays, then the horizon line on top.
  canvas
    ..drawLine(Offset(x(30), y(12)), Offset(x(30), y(18.5)), rays)
    ..drawLine(Offset(x(44), y(20)), Offset(x(40.5), y(23.5)), rays)
    ..drawLine(Offset(x(16), y(20)), Offset(x(19.5), y(23.5)), rays)
    ..drawLine(Offset(x(9), y(38.2)), Offset(x(51), y(38.2)), line);
}

/// The in-app Horizon mark — a [CustomPaint] of [paintHorizon] at [size].
/// Defaults to the brand teal field with a white horizon + gold sun (the app-
/// icon lockup); pass `field: null` for the mark alone on an existing surface.
class HorizonMark extends StatelessWidget {
  const HorizonMark({
    required this.size,
    this.field = kBrandTeal,
    this.ink = Colors.white,
    this.sun = kBrandGold,
    this.markScale = 0.62,
    super.key,
  });

  final double size;
  final Color? field;
  final Color ink;
  final Color sun;
  final double markScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _HorizonPainter(
          field: field,
          ink: ink,
          sun: sun,
          markScale: markScale,
        ),
      ),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  const _HorizonPainter({
    required this.field,
    required this.ink,
    required this.sun,
    required this.markScale,
  });

  final Color? field;
  final Color ink;
  final Color sun;
  final double markScale;

  @override
  void paint(Canvas canvas, Size size) => paintHorizon(
    canvas,
    size,
    field: field,
    ink: ink,
    sun: sun,
    markScale: markScale,
  );

  @override
  bool shouldRepaint(_HorizonPainter old) =>
      old.field != field ||
      old.ink != ink ||
      old.sun != sun ||
      old.markScale != markScale;
}
