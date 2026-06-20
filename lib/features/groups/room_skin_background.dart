import 'dart:async';
import 'dart:math';

import 'package:differentworld/features/groups/room_skins.dart';
import 'package:flutter/material.dart';

/// The painted ambience for a [RoomSkin] — a deep-field gradient + a cheap
/// signature texture (stars, light shafts, a skyline) with gentle MICRO-MOTION
/// (twinkle, drift, rise, fall, shimmer). NOT a literal scene: the "color lives
/// in the ambience, not the ink" idiom (docs/VISION.md "two layers of skin").
/// It reads behind content, costs almost nothing, and coheres with the
/// floating-glass chrome.
///
/// Fills its parent's constraints. **`animate` is opt-in (default false)** so a
/// grid of six room CARD thumbnails stays static (six tickers would be wasteful
/// — the original perf note); a full-screen room background passes
/// `animate: true` for the living micro-motion. `skin: null` renders nothing
/// (the safe fallback for an unset / unknown room_skin).
class RoomSkinBackground extends StatefulWidget {
  const RoomSkinBackground({
    required this.skin,
    this.child,
    this.decal = false,
    this.animate = false,
    super.key,
  });

  final RoomSkin? skin;

  /// Optional content painted OVER the ambience (e.g. a room name in glass).
  final Widget? child;

  /// Light **decal** mode — paints NO dark gradient, only a subtle
  /// accent-tinted edge motif over a transparent background, so it reads as a
  /// gentle theme nod behind warm-paper Calm content. `false` (default) → the
  /// full immersive deep-field ambience (white/glass content floats over it).
  final bool decal;

  /// When true, run a slow looping ticker so the signature's particles drift /
  /// twinkle / fall. ONE controller per instance — opt in only for a
  /// full-screen background, never a grid of thumbnails.
  final bool animate;

  @override
  State<RoomSkinBackground> createState() => _RoomSkinBackgroundState();
}

class _RoomSkinBackgroundState extends State<RoomSkinBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  @override
  void initState() {
    super.initState();
    if (widget.animate) _start();
  }

  void _start() {
    // A long loop — the per-frame delta is tiny, so the motion reads as a calm
    // ambient drift, not a busy animation. repeat() keeps it going.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 36),
    );
    unawaited(_ctrl!.repeat());
  }

  @override
  void didUpdateWidget(RoomSkinBackground old) {
    super.didUpdateWidget(old);
    if (widget.animate && _ctrl == null) {
      _start();
    } else if (!widget.animate && _ctrl != null) {
      _ctrl!.dispose();
      _ctrl = null;
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.skin;
    if (s == null) return widget.child ?? const SizedBox.shrink();
    return RepaintBoundary(
      child: CustomPaint(
        painter: _RoomSkinPainter(s, decal: widget.decal, anim: _ctrl),
        child: widget.child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _RoomSkinPainter extends CustomPainter {
  _RoomSkinPainter(this.skin, {this.decal = false, this.anim})
    : super(repaint: anim);

  final RoomSkin skin;
  final bool decal;
  final Animation<double>? anim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = anim?.value ?? 0.0; // 0..1, looping (0 when static)
    // Decal mode: no gradient (the warm-paper screen shows through), just the
    // subtle accent-tinted edge motif. Unknown id → nothing (safe).
    if (decal) {
      _decalSignatures[skin.id]?.call(canvas, size, skin, t);
      return;
    }
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
    _signatures[skin.id]?.call(canvas, size, skin, t);
  }

  @override
  bool shouldRepaint(_RoomSkinPainter old) =>
      old.skin.id != skin.id || old.decal != decal || old.anim != anim;
}

/// id → signature painter `(canvas, size, skin, t)` where `t` is a 0..1 loop
/// (0 when static). Adding a skin's look is one entry here (+ a row in
/// `kRoomSkins`). Each is seeded-deterministic and density-clamped so it reads
/// the same and stays legible from a card thumbnail to a full-screen hero.
int _areaCount(Size s, double per, int min, int max) =>
    ((s.width * s.height) / per).round().clamp(min, max);

/// Wrap a value into [0, max) — for particles that drift/fall and loop.
double _wrap(double v, double max) {
  final m = v % max;
  return m < 0 ? m + max : m;
}

typedef _Sig = void Function(Canvas, Size, RoomSkin, double);

final Map<String, _Sig> _signatures = {
  // Starfield (each star twinkles on its own phase) + a soft planet low-right +
  // a periodic shooting star streaking across the upper field.
  'space': (canvas, s, skin, t) {
    final r = Random(11);
    final star = Paint();
    final n = _areaCount(s, 1800, 14, 70);
    for (var i = 0; i < n; i++) {
      final base = 0.25 + r.nextDouble() * 0.6;
      // Twinkle: a slow per-star sine on the alpha.
      final tw = 0.7 + 0.3 * sin((t + r.nextDouble()) * 2 * pi);
      star.color = Colors.white.withValues(alpha: (base * tw).clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(r.nextDouble() * s.width, r.nextDouble() * s.height),
        0.4 + r.nextDouble() * 1.1,
        star,
      );
    }
    // Shooting star: one streak, sweeping across the top third early in the loop.
    if (t < 0.35) {
      final p = t / 0.35; // 0..1 across the sweep
      final sx = s.width * (-0.1 + p * 1.2);
      final sy = s.height * (0.08 + p * 0.12);
      final tail = s.shortestSide * 0.12;
      canvas.drawLine(
        Offset(sx, sy),
        Offset(sx - tail, sy - tail * 0.4),
        Paint()
          ..color = Colors.white.withValues(alpha: (1 - p) * 0.7)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
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
  // Diagonal caustic light shafts (slow shimmer) + rising motes.
  'underwater': (canvas, s, skin, t) {
    for (var i = 0; i < 4; i++) {
      final x = s.width * (0.15 + i * 0.22);
      final sh = 0.07 + 0.04 * sin((t + i * 0.2) * 2 * pi);
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + s.width * 0.1, 0)
          ..lineTo(x - s.width * 0.05, s.height)
          ..lineTo(x - s.width * 0.18, s.height)
          ..close(),
        Paint()..color = skin.color.withValues(alpha: sh.clamp(0.0, 1.0)),
      );
    }
    final r = Random(23);
    final mote = Paint();
    final n = _areaCount(s, 4000, 8, 36);
    for (var i = 0; i < n; i++) {
      final x0 = r.nextDouble() * s.width;
      final y0 = r.nextDouble() * s.height;
      // Rise: motes drift upward and wrap, each at its own speed.
      final speed = 0.4 + r.nextDouble() * 0.6;
      final y = _wrap(y0 - t * s.height * speed, s.height);
      final x = x0 + sin((t + r.nextDouble()) * 2 * pi) * 3;
      mote.color = Colors.white.withValues(alpha: 0.1 + r.nextDouble() * 0.18);
      canvas.drawCircle(Offset(x, y), 0.8 + r.nextDouble() * 1.4, mote);
    }
  },
  // A skyline silhouette with lit windows that occasionally flicker.
  'urban': (canvas, s, skin, t) {
    final r = Random(31);
    final building = Paint()..color = Colors.black.withValues(alpha: 0.32);
    var x = 0.0;
    var wi = 0;
    while (x < s.width) {
      final w = s.width * (0.06 + r.nextDouble() * 0.08);
      final h = s.height * (0.2 + r.nextDouble() * 0.4);
      final rect = Rect.fromLTWH(x, s.height - h, w, h);
      canvas.drawRect(rect, building);
      for (var wy = rect.top + 6; wy < rect.bottom - 4; wy += 9) {
        for (var wx = rect.left + 4; wx < rect.right - 3; wx += 8) {
          final lit = r.nextDouble();
          if (lit > 0.45) {
            // A few windows flicker on the loop; most hold steady.
            final flicker = lit > 0.9
                ? (0.5 + 0.5 * sin((t * 3 + wi) * 2 * pi)).clamp(0.15, 1.0)
                : 1.0;
            canvas.drawRect(
              Rect.fromLTWH(wx, wy, 2.5, 3.5),
              Paint()..color = skin.color.withValues(alpha: 0.5 * flicker),
            );
          }
          wi++;
        }
      }
      x += w + s.width * 0.015;
    }
  },
  // A low warm sun that breathes + a horizon band.
  'safari': (canvas, s, skin, t) {
    final sun = Offset(s.width * 0.74, s.height * 0.34);
    final pulse = 1 + 0.04 * sin(t * 2 * pi);
    final rad = s.shortestSide * 0.18 * pulse;
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
  // Soft clouds drifting slowly sideways (wrapping).
  'travel': (canvas, s, skin, t) {
    final r = Random(41);
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.11);
    for (var i = 0; i < 5; i++) {
      final drift = 0.3 + r.nextDouble() * 0.5;
      final cx = _wrap(
        r.nextDouble() * s.width + t * s.width * drift,
        s.width * 1.3,
      ) - s.width * 0.15;
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
  // A tree-line silhouette + dappled light + drifting fireflies.
  'forest': (canvas, s, skin, t) {
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
      final shimmer = 0.6 + 0.4 * sin((t + r.nextDouble()) * 2 * pi);
      dap.color = skin.color.withValues(
        alpha: ((0.06 + r.nextDouble() * 0.08) * shimmer).clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        Offset(r.nextDouble() * s.width, r.nextDouble() * s.height * 0.6),
        2 + r.nextDouble() * 4,
        dap,
      );
    }
    // Fireflies — a few glowing motes tracing slow little orbits.
    final fly = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var i = 0; i < 5; i++) {
      final ph = r.nextDouble();
      final ox = sin((t + ph) * 2 * pi) * s.width * 0.04;
      final oy = cos((t + ph) * 2 * pi) * s.height * 0.03;
      final pulse = (0.4 + 0.6 * sin((t * 2 + ph) * 2 * pi)).clamp(0.0, 1.0);
      fly.color = skin.color.withValues(alpha: 0.5 * pulse);
      canvas.drawCircle(
        Offset(
          s.width * (0.15 + r.nextDouble() * 0.7) + ox,
          s.height * (0.35 + r.nextDouble() * 0.4) + oy,
        ),
        1.6,
        fly,
      );
    }
  },
  // Aurora ribbons that shimmer + sparse falling snow.
  'arctic': (canvas, s, skin, t) {
    for (var i = 0; i < 3; i++) {
      final y = s.height * (0.2 + i * 0.12);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= s.width; x += s.width / 6) {
        path.lineTo(
          x,
          y + sin(x / s.width * pi * 2 + i + t * 2 * pi) * s.height * 0.05,
        );
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
      final x0 = r.nextDouble() * s.width;
      final y0 = r.nextDouble() * s.height;
      final speed = 0.3 + r.nextDouble() * 0.5;
      final y = _wrap(y0 + t * s.height * speed, s.height);
      final x = x0 + sin((t + r.nextDouble()) * 2 * pi) * 4;
      snow.color = Colors.white.withValues(alpha: 0.2 + r.nextDouble() * 0.4);
      canvas.drawCircle(Offset(x, y), 0.7 + r.nextDouble() * 1.2, snow);
    }
  },
};

/// id → a SUBTLE decal motif for [RoomSkinBackground]'s light mode: the room's
/// signature element, accent-tinted + low-alpha + edge-confined, over a
/// TRANSPARENT background so warm-paper Calm content reads through. The Calm
/// counterpart to `_signatures` (the full immersive deep field). `t` adds the
/// same gentle micro-motion, dialled down for the quieter decal.
final Map<String, _Sig> _decalSignatures = {
  // A top-corner constellation (twinkling) + a small soft planet.
  'space': (canvas, s, skin, t) {
    final r = Random(11);
    final star = Paint();
    final n = _areaCount(s, 7000, 8, 24);
    for (var i = 0; i < n; i++) {
      final tw = 0.75 + 0.25 * sin((t + r.nextDouble()) * 2 * pi);
      star.color = skin.color.withValues(
        alpha: ((0.16 + r.nextDouble() * 0.22) * tw).clamp(0.0, 1.0),
      );
      canvas.drawCircle(
        Offset(
          s.width * (0.5 + r.nextDouble() * 0.5),
          s.height * r.nextDouble() * 0.32,
        ),
        0.5 + r.nextDouble() * 1.1,
        star,
      );
    }
    final pc = Offset(s.width * 0.9, s.height * 0.1);
    final pr = s.shortestSide * 0.06;
    canvas
      ..drawCircle(
        pc,
        pr * 1.7,
        Paint()
          ..color = skin.color.withValues(alpha: 0.07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      )
      ..drawCircle(pc, pr, Paint()..color = skin.color.withValues(alpha: 0.16));
  },
  // Faint caustic shafts from the top + a few rising bubble outlines low.
  'underwater': (canvas, s, skin, t) {
    final shaft = Paint()..color = skin.color.withValues(alpha: 0.05);
    for (var i = 0; i < 3; i++) {
      final x = s.width * (0.2 + i * 0.3);
      canvas.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + s.width * 0.08, 0)
          ..lineTo(x - s.width * 0.04, s.height * 0.45)
          ..lineTo(x - s.width * 0.13, s.height * 0.45)
          ..close(),
        shaft,
      );
    }
    final r = Random(23);
    final bubble = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 10; i++) {
      final y0 = s.height * (0.6 + r.nextDouble() * 0.4);
      final speed = 0.25 + r.nextDouble() * 0.4;
      final y = _wrap(y0 - t * s.height * speed, s.height * 0.5) + s.height * 0.5;
      bubble.color = skin.color.withValues(alpha: 0.12 + r.nextDouble() * 0.12);
      canvas.drawCircle(
        Offset(s.width * r.nextDouble(), y),
        1.5 + r.nextDouble() * 3,
        bubble,
      );
    }
  },
  // A low, faint skyline band.
  'urban': (canvas, s, skin, t) {
    final r = Random(31);
    final b = Paint()..color = skin.color.withValues(alpha: 0.10);
    var x = 0.0;
    while (x < s.width) {
      final w = s.width * (0.06 + r.nextDouble() * 0.08);
      final h = s.height * (0.05 + r.nextDouble() * 0.10);
      canvas.drawRect(Rect.fromLTWH(x, s.height - h, w, h), b);
      x += w + s.width * 0.02;
    }
  },
  // A soft, gently-breathing sun in the top corner.
  'safari': (canvas, s, skin, t) {
    final sun = Offset(s.width * 0.87, s.height * 0.12);
    final rad = s.shortestSide * 0.08 * (1 + 0.05 * sin(t * 2 * pi));
    canvas
      ..drawCircle(
        sun,
        rad * 1.9,
        Paint()
          ..color = skin.color.withValues(alpha: 0.08)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      )
      ..drawCircle(sun, rad, Paint()..color = skin.color.withValues(alpha: 0.2));
  },
  // A couple of clouds drifting slowly near the top.
  'travel': (canvas, s, skin, t) {
    final r = Random(41);
    final cloud = Paint()..color = skin.color.withValues(alpha: 0.07);
    for (var i = 0; i < 3; i++) {
      final drift = 0.2 + r.nextDouble() * 0.3;
      final cx = _wrap(
        s.width * (0.3 + r.nextDouble() * 0.6) + t * s.width * drift,
        s.width * 1.2,
      ) - s.width * 0.1;
      final cy = s.height * (0.06 + r.nextDouble() * 0.16);
      final base = s.shortestSide * 0.07;
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
  // A low, faint tree-line + a couple of drifting fireflies.
  'forest': (canvas, s, skin, t) {
    final r = Random(53);
    final tree = Paint()..color = skin.color.withValues(alpha: 0.12);
    var x = 0.0;
    while (x < s.width) {
      final w = s.width * (0.05 + r.nextDouble() * 0.05);
      final h = s.height * (0.07 + r.nextDouble() * 0.11);
      canvas.drawPath(
        Path()
          ..moveTo(x + w / 2, s.height - h)
          ..lineTo(x, s.height)
          ..lineTo(x + w, s.height)
          ..close(),
        tree,
      );
      x += w * 0.85;
    }
    final fly = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
    for (var i = 0; i < 3; i++) {
      final ph = r.nextDouble();
      final ox = sin((t + ph) * 2 * pi) * s.width * 0.03;
      final pulse = (0.4 + 0.6 * sin((t * 2 + ph) * 2 * pi)).clamp(0.0, 1.0);
      fly.color = skin.color.withValues(alpha: 0.3 * pulse);
      canvas.drawCircle(
        Offset(
          s.width * (0.2 + r.nextDouble() * 0.6) + ox,
          s.height * (0.5 + r.nextDouble() * 0.3),
        ),
        1.5,
        fly,
      );
    }
  },
  // A faint aurora ribbon that shimmers near the top.
  'arctic': (canvas, s, skin, t) {
    for (var i = 0; i < 2; i++) {
      final y = s.height * (0.08 + i * 0.06);
      final path = Path()..moveTo(0, y);
      for (var x = 0.0; x <= s.width; x += s.width / 6) {
        path.lineTo(
          x,
          y + sin(x / s.width * pi * 2 + i + t * 2 * pi) * s.height * 0.03,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = skin.color.withValues(alpha: 0.12 - i * 0.04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6 + i * 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
  },
};
