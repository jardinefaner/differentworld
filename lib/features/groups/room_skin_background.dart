import 'dart:math';

import 'package:differentworld/features/groups/room_skins.dart';
import 'package:flutter/material.dart';

/// The painted ambience for a [RoomSkin] — a deep-field gradient + a cheap
/// signature texture (stars, light shafts, a skyline). NOT a literal scene:
/// the "color lives in the ambience, not the ink" idiom (docs/VISION.md "two
/// layers of skin"; the design-council Art Director call) so it reads behind
/// content, costs almost nothing, and coheres with the floating-glass chrome.
///
/// Fills its parent's constraints. Static (`shouldRepaint` is id-only,
/// seeded-deterministic) so six room cards don't each animate — motion is a
/// deliberate follow-up, not v1. `skin: null` renders nothing (the safe
/// fallback for an unset / unknown room_skin).
class RoomSkinBackground extends StatelessWidget {
  const RoomSkinBackground({required this.skin, this.child, super.key});

  final RoomSkin? skin;

  /// Optional content painted OVER the ambience (e.g. a room name in glass).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final s = skin;
    if (s == null) return child ?? const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RoomSkinPainter(s),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _RoomSkinPainter extends CustomPainter {
  const _RoomSkinPainter(this.skin);

  final RoomSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    // 1. The deep-field gradient (the ambience).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [skin.bgTop, skin.bgBottom],
        ).createShader(rect),
    );
    // 2. The signature texture (the ink). Unknown id → gradient only.
    _signatures[skin.id]?.call(canvas, size, skin);
  }

  @override
  bool shouldRepaint(_RoomSkinPainter old) => old.skin.id != skin.id;
}

/// id → signature painter. Adding a skin's look is one entry here (+ a row in
/// `kRoomSkins`). Each is seeded-deterministic and density-clamped so it reads
/// the same and stays legible from a card thumbnail to a full-screen hero.
int _areaCount(Size s, double per, int min, int max) =>
    ((s.width * s.height) / per).round().clamp(min, max);

final Map<String, void Function(Canvas, Size, RoomSkin)> _signatures = {
  // Starfield + a soft planet low-right.
  'space': (canvas, s, skin) {
    final r = Random(11);
    final star = Paint();
    final n = _areaCount(s, 1800, 14, 70);
    for (var i = 0; i < n; i++) {
      star.color = Colors.white.withValues(alpha: 0.25 + r.nextDouble() * 0.6);
      canvas.drawCircle(
        Offset(r.nextDouble() * s.width, r.nextDouble() * s.height),
        0.4 + r.nextDouble() * 1.1,
        star,
      );
    }
    final pc = Offset(s.width * 0.82, s.height * 0.8);
    final pr = s.shortestSide * 0.24;
    canvas
      ..drawCircle(
        pc,
        pr * 1.5,
        Paint()
          ..color = skin.color.withValues(alpha: 0.14)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      )
      ..drawCircle(pc, pr, Paint()..color = skin.color.withValues(alpha: 0.3));
  },
  // Diagonal caustic light shafts + rising motes.
  'underwater': (canvas, s, skin) {
    final shaft = Paint()..color = skin.color.withValues(alpha: 0.09);
    for (var i = 0; i < 4; i++) {
      final x = s.width * (0.15 + i * 0.22);
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + s.width * 0.1, 0)
          ..lineTo(x - s.width * 0.05, s.height)
          ..lineTo(x - s.width * 0.18, s.height)
          ..close(),
        shaft,
      );
    }
    final r = Random(23);
    final mote = Paint();
    final n = _areaCount(s, 4000, 8, 36);
    for (var i = 0; i < n; i++) {
      mote.color = Colors.white.withValues(alpha: 0.1 + r.nextDouble() * 0.18);
      canvas.drawCircle(
        Offset(r.nextDouble() * s.width, r.nextDouble() * s.height),
        0.8 + r.nextDouble() * 1.4,
        mote,
      );
    }
  },
  // A skyline silhouette with lit windows along the bottom.
  'urban': (canvas, s, skin) {
    final r = Random(31);
    final building = Paint()..color = Colors.black.withValues(alpha: 0.32);
    final win = Paint()..color = skin.color.withValues(alpha: 0.5);
    var x = 0.0;
    while (x < s.width) {
      final w = s.width * (0.06 + r.nextDouble() * 0.08);
      final h = s.height * (0.2 + r.nextDouble() * 0.4);
      final rect = Rect.fromLTWH(x, s.height - h, w, h);
      canvas.drawRect(rect, building);
      for (var wy = rect.top + 6; wy < rect.bottom - 4; wy += 9) {
        for (var wx = rect.left + 4; wx < rect.right - 3; wx += 8) {
          if (r.nextDouble() > 0.45) {
            canvas.drawRect(Rect.fromLTWH(wx, wy, 2.5, 3.5), win);
          }
        }
      }
      x += w + s.width * 0.015;
    }
  },
  // A low warm sun + a horizon band.
  'safari': (canvas, s, skin) {
    final sun = Offset(s.width * 0.74, s.height * 0.34);
    final rad = s.shortestSide * 0.18;
    canvas
      ..drawCircle(
        sun,
        rad * 2,
        Paint()
          ..color = skin.color.withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      )
      ..drawCircle(sun, rad, Paint()..color = skin.color.withValues(alpha: 0.32));
    final hy = s.height * 0.66;
    canvas.drawRect(
      Rect.fromLTWH(0, hy, s.width, s.height - hy),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
  },
  // Soft drifting clouds.
  'travel': (canvas, s, skin) {
    final r = Random(41);
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.11);
    for (var i = 0; i < 4; i++) {
      final cx = r.nextDouble() * s.width;
      final cy = s.height * (0.12 + r.nextDouble() * 0.4);
      final base = s.shortestSide * (0.1 + r.nextDouble() * 0.08);
      for (var j = 0; j < 4; j++) {
        canvas.drawCircle(
          Offset(
            cx + (j - 1.5) * base * 0.7,
            cy + (r.nextDouble() - 0.5) * base * 0.3,
          ),
          base * (0.7 + r.nextDouble() * 0.4),
          cloud,
        );
      }
    }
  },
  // A tree-line silhouette + dappled light.
  'forest': (canvas, s, skin) {
    final r = Random(53);
    final tree = Paint()..color = Colors.black.withValues(alpha: 0.26);
    var x = 0.0;
    while (x < s.width) {
      final w = s.width * (0.05 + r.nextDouble() * 0.05);
      final h = s.height * (0.3 + r.nextDouble() * 0.4);
      canvas.drawPath(
        Path()
          ..moveTo(x + w / 2, s.height - h)
          ..lineTo(x, s.height)
          ..lineTo(x + w, s.height)
          ..close(),
        tree,
      );
      x += w * 0.8;
    }
    final dap = Paint();
    final n = _areaCount(s, 6000, 6, 24);
    for (var i = 0; i < n; i++) {
      dap.color = skin.color.withValues(alpha: 0.06 + r.nextDouble() * 0.08);
      canvas.drawCircle(
        Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * 0.6),
        2 + r.nextDouble() * 4,
        dap,
      );
    }
  },
  // Aurora ribbons + sparse snow.
  'arctic': (canvas, s, skin) {
    for (var i = 0; i < 3; i++) {
      final y = s.height * (0.2 + i * 0.12);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= s.width; x += s.width / 6) {
        path.lineTo(x, y + sin(x / s.width * pi * 2 + i) * s.height * 0.05);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = skin.color.withValues(alpha: 0.14 - i * 0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8 + i * 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }
    final r = Random(67);
    final snow = Paint();
    final n = _areaCount(s, 3500, 8, 40);
    for (var i = 0; i < n; i++) {
      snow.color = Colors.white.withValues(alpha: 0.2 + r.nextDouble() * 0.4);
      canvas.drawCircle(
        Offset(r.nextDouble() * s.width, r.nextDouble() * s.height),
        0.7 + r.nextDouble() * 1.2,
        snow,
      );
    }
  },
};
