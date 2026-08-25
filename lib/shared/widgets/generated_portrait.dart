import 'dart:math';

import 'package:flutter/material.dart';

/// A drawn portrait, generated from a seed — the no-photo state for a person
/// (docs/BRAND.md), borrowed from the Feature Lab's `portrait_avatar.dart`
/// and re-tuned for children.
///
/// **The whole trick is that nothing is randomised on a continuous scale.**
/// Random hue and random lightness is exactly what makes generated avatars
/// look generated. Every colour here comes from a hand-picked set chosen to
/// sit together, and the seed only ever chooses *which* member of a set —
/// never a raw number. Silhouette does the identifying work, because at 20dp
/// in a list that is all that survives.
///
/// **What was deliberately dropped from the Lab's version: beards and
/// glasses.** On an adult team they are charming variety. On a six-year-old,
/// displayed in front of that six-year-old, a generated face wearing a beard
/// is not variety — it is the app making a wrong claim about a child in
/// public. Every trait that survives (hair shape, colouring, face width,
/// freckles) reads as decoration; none of them reads as a statement about
/// what this particular person looks like.
///
/// Off by default — see `generatedPortraitsProvider`. `PersonAvatar` renders
/// initials unless a director has opted in.
class GeneratedPortrait extends StatelessWidget {
  const GeneratedPortrait({required this.seed, this.size = 40, super.key});

  /// Stable per-person string — a name or an id. The same seed always
  /// produces the same face, on every device and across restarts.
  final String seed;

  /// Diameter in logical pixels.
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          painter: _PortraitPainter(seed),
          size: Size(size, size),
        ),
      ),
    );
  }
}

// ── curated sets ────────────────────────────────────────────────────────────
// Hardcoded on purpose, and allowlisted in check_theme_adherence.sh: skin and
// hair are content, not chrome. No ColorScheme governs what colour a person
// is, and re-tinting these per theme would be worse than meaningless.

const _skin = [
  Color(0xFF8D5524),
  Color(0xFFC68642),
  Color(0xFFE0AC69),
  Color(0xFFF1C27D),
  Color(0xFFFFDBAC),
  Color(0xFF5C3317),
  Color(0xFF6F4E37),
  Color(0xFFA9746E),
];

/// No grey and no white, for the same reason there are no beards: they are
/// not neutral decoration on a child, they are the portrait asserting an age.
/// Blonde and ginger replace them and keep the light end of the range.
const _hairColors = [
  Color(0xFF1C1712),
  Color(0xFF2E2119),
  Color(0xFF4A3423),
  Color(0xFF6B4A2F),
  Color(0xFF9A6A3C),
  Color(0xFFC9A66B),
  Color(0xFFE0C084),
  Color(0xFFB5541F),
  Color(0xFF7B3F3F),
];

/// Muted enough to sit under a face without competing with it, and to survive
/// being 20dp wide next to twenty others.
const _backdrops = [
  Color(0xFF3E5C50),
  Color(0xFF4A5D6E),
  Color(0xFF6E5A4A),
  Color(0xFF5B4A5E),
  Color(0xFF6E6046),
  Color(0xFF44605E),
  Color(0xFF6B4C4C),
  Color(0xFF4E5A44),
];

/// Head coverings get their OWN palette, deliberately more saturated than
/// [_backdrops]. Drawing a wrap in a backdrop colour — as the Lab's version
/// did — makes it vanish into the circle behind it and the portrait reads as
/// a bald head, which is both wrong and the one silhouette this set does not
/// otherwise contain.
const _wraps = [
  Color(0xFF8C4A3F),
  Color(0xFF3F6C8C),
  Color(0xFF6B5FA8),
  Color(0xFF2F7A62),
  Color(0xFF9A6B2F),
  Color(0xFF8A3F6B),
];

const _clothes = [
  Color(0xFF2C3A3F),
  Color(0xFF3F3A2C),
  Color(0xFF3A2C3F),
  Color(0xFF2C3F35),
  Color(0xFF4A3F3A),
  Color(0xFF35323E),
];

enum _Hair { cropped, short, sideParted, bob, long, bun, wrap, curls }

class _Traits {
  const _Traits({
    required this.skin,
    required this.hairColor,
    required this.backdrop,
    required this.clothes,
    required this.wrap,
    required this.hair,
    required this.faceWidth,
    required this.smiling,
    required this.freckles,
  });

  factory _Traits.fromSeed(String seed) {
    final rng = _Lcg(stablePortraitHash(seed));
    return _Traits(
      skin: _skin[rng.pick(_skin.length)],
      hairColor: _hairColors[rng.pick(_hairColors.length)],
      backdrop: _backdrops[rng.pick(_backdrops.length)],
      clothes: _clothes[rng.pick(_clothes.length)],
      wrap: _wraps[rng.pick(_wraps.length)],
      hair: _Hair.values[rng.pick(_Hair.values.length)],
      // Three widths, not a continuous range — narrow variation reads as a
      // rendering wobble, discrete variation reads as a different person.
      faceWidth: const [0.235, 0.255, 0.275][rng.pick(3)],
      // Mostly smiling. A neutral mouth is fine as variety; a room of them
      // is not the register this app is in.
      smiling: rng.pick(4) != 0,
      freckles: rng.pick(5) == 0,
    );
  }

  final Color skin;
  final Color hairColor;
  final Color backdrop;
  final Color clothes;
  final Color wrap;
  final _Hair hair;
  final double faceWidth;
  final bool smiling;
  final bool freckles;
}

/// `String.hashCode` is not stable across runs or platforms, and a face that
/// changes on restart is a bug people notice instantly.
int stablePortraitHash(String value) {
  var hash = 5381;
  for (final unit in value.codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0x7fffffff;
  }
  return hash;
}

/// Small deterministic generator so trait choice is reproducible and evenly
/// spread, without pulling in a dependency.
class _Lcg {
  _Lcg(this._state);
  int _state;

  int pick(int n) {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return (_state >> 16) % n;
  }
}

class _PortraitPainter extends CustomPainter {
  _PortraitPainter(this.seed) : t = _Traits.fromSeed(seed);

  final String seed;
  final _Traits t;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()..isAntiAlias = true;
    double x(double u) => u * s;
    double y(double v) => v * s;

    canvas.drawRect(Offset.zero & size, paint..color = t.backdrop);

    final faceW = t.faceWidth * s;
    final faceH = faceW * 1.22;
    final faceCentre = Offset(x(0.5), y(0.455));
    final hairBack = t.hairColor;

    // Hair that sits BEHIND the head — drawn first so the face overlaps it.
    switch (t.hair) {
      case _Hair.long:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x(0.5), y(0.60)),
              width: faceW * 2.25,
              height: faceH * 1.95,
            ),
            Radius.circular(faceW * 0.85),
          ),
          paint..color = hairBack,
        );
      case _Hair.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(x(0.5), y(0.50)),
              width: faceW * 2.35,
              height: faceH * 1.55,
            ),
            Radius.circular(faceW * 0.8),
          ),
          paint..color = hairBack,
        );
      case _Hair.curls:
        for (var i = 0; i < 7; i++) {
          final a = pi * (0.12 + i / 7 * 0.76);
          canvas.drawCircle(
            faceCentre.translate(
              -cos(a) * faceW * 1.02,
              -sin(a) * faceH * 0.92,
            ),
            faceW * 0.36,
            paint..color = hairBack,
          );
        }
      case _Hair.bun:
        canvas.drawCircle(
          Offset(x(0.5), y(0.16)),
          faceW * 0.40,
          paint..color = hairBack,
        );
      case _Hair.cropped:
      case _Hair.short:
      case _Hair.sideParted:
      case _Hair.wrap:
        break;
    }

    // Shoulders — a torso, so the portrait reads as a person and not a head.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x(0.5), y(1.12)),
          width: s * 1.02,
          height: s * 0.62,
        ),
        Radius.circular(s * 0.26),
      ),
      paint..color = t.clothes,
    );

    // Neck, before the face so the jaw sits over it.
    // Each draw call is a named body part with its own comment and its own
    // paint colour; cascading them into one statement would bury both.
    // ignore: cascade_invocations
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x(0.5), y(0.78)),
          width: faceW * 0.62,
          height: faceH * 0.42,
        ),
        Radius.circular(faceW * 0.2),
      ),
      paint..color = _shade(t.skin, 0.88),
    );

    // Ears, only when hair won't cover them.
    if (t.hair == _Hair.cropped) {
      for (final dir in <double>[-1, 1]) {
        canvas.drawCircle(
          faceCentre.translate(dir * faceW * 0.98, faceH * 0.06),
          faceW * 0.18,
          paint..color = _shade(t.skin, 0.94),
        );
      }
    }

    // Face.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: faceCentre,
          width: faceW * 2,
          height: faceH * 2,
        ),
        Radius.circular(faceW * 0.92),
      ),
      paint..color = t.skin,
    );

    // Hair that sits IN FRONT of the head. Each style has to change the
    // OUTLINE, not just the depth of the same cap — at 40dp in a grid the
    // silhouette is the only thing telling two people apart.
    final hairPaint = paint..color = hairBack;
    switch (t.hair) {
      case _Hair.cropped:
        // Tight to the skull, high hairline, ears out.
        _cap(canvas, faceCentre, faceW, faceH, 0.62, hairPaint);
      case _Hair.short:
        // Cap plus a blunt fringe across the brow.
        _cap(canvas, faceCentre, faceW, faceH, 0.74, hairPaint);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: faceCentre.translate(0, -faceH * 0.66),
              width: faceW * 1.78,
              height: faceH * 0.30,
            ),
            Radius.circular(faceW * 0.14),
          ),
          hairPaint,
        );
      case _Hair.curls:
      case _Hair.bun:
      case _Hair.long:
        _cap(canvas, faceCentre, faceW, faceH, 0.78, hairPaint);
      case _Hair.bob:
        // Two panels down past the jaw — the frame is the whole silhouette.
        _cap(canvas, faceCentre, faceW, faceH, 0.80, hairPaint);
        for (final dir in [-1.0, 1.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: faceCentre.translate(dir * faceW * 0.96, faceH * 0.18),
                width: faceW * 0.46,
                height: faceH * 1.42,
              ),
              Radius.circular(faceW * 0.22),
            ),
            hairPaint,
          );
        }
      case _Hair.sideParted:
        final path = Path()
          ..moveTo(faceCentre.dx - faceW, faceCentre.dy - faceH * 0.30)
          ..quadraticBezierTo(
            faceCentre.dx - faceW * 0.9,
            faceCentre.dy - faceH * 1.05,
            faceCentre.dx + faceW * 0.35,
            faceCentre.dy - faceH * 0.98,
          )
          ..quadraticBezierTo(
            faceCentre.dx + faceW * 1.02,
            faceCentre.dy - faceH * 0.86,
            faceCentre.dx + faceW * 0.98,
            faceCentre.dy - faceH * 0.34,
          )
          ..quadraticBezierTo(
            faceCentre.dx + faceW * 0.5,
            faceCentre.dy - faceH * 0.68,
            faceCentre.dx - faceW * 0.2,
            faceCentre.dy - faceH * 0.52,
          )
          ..close();
        canvas.drawPath(path, hairPaint);
      case _Hair.wrap:
        // A covering, not hair: it comes down over the ears and the brow.
        // The opening is deliberately smaller than the head so there is a
        // visible band across the forehead — without it the wrap reads as a
        // swim cap at best and a bald head at worst.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: faceCentre.translate(0, -faceH * 0.10),
              width: faceW * 2.34,
              height: faceH * 1.90,
            ),
            Radius.circular(faceW * 0.74),
          ),
          paint..color = t.wrap,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: faceCentre.translate(0, faceH * 0.10),
              width: faceW * 1.62,
              height: faceH * 1.46,
            ),
            Radius.circular(faceW * 0.68),
          ),
          paint..color = t.skin,
        );
    }

    // Features. Kept bold on purpose — hairlines vanish at list size.
    final eyeY = faceCentre.dy + faceH * 0.06;
    final eyeDx = faceW * 0.42;
    final ink = paint..color = const Color(0xFF20160F);

    for (final dir in [-1.0, 1.0]) {
      canvas.drawCircle(
        Offset(faceCentre.dx + dir * eyeDx, eyeY),
        max(faceW * 0.105, 1.1),
        ink,
      );
      // Brow above the eye — separate paint, kept a separate statement so
      // the two features stay readable side by side.
      // ignore: cascade_invocations
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(faceCentre.dx + dir * eyeDx, eyeY - faceH * 0.26),
            width: faceW * 0.42,
            height: max(faceW * 0.09, 1),
          ),
          const Radius.circular(4),
        ),
        paint..color = _shade(t.hairColor, 0.9),
      );
    }

    final mouthY = faceCentre.dy + faceH * 0.42;
    final mouth = Paint()
      ..color = const Color(0xFF20160F).withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = max(faceW * 0.10, 1.2)
      ..isAntiAlias = true;
    if (t.smiling) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(faceCentre.dx, mouthY - faceH * 0.10),
          width: faceW * 0.62,
          height: faceH * 0.38,
        ),
        0.25 * pi,
        0.5 * pi,
        false,
        mouth,
      );
    } else {
      canvas.drawLine(
        Offset(faceCentre.dx - faceW * 0.22, mouthY),
        Offset(faceCentre.dx + faceW * 0.22, mouthY),
        mouth,
      );
    }

    // Below this the dots read as dirt on the screen, not freckles.
    if (t.freckles && s > 44) {
      final f = paint..color = _shade(t.skin, 0.78);
      for (var i = 0; i < 6; i++) {
        final side = i.isEven ? -1 : 1;
        canvas.drawCircle(
          faceCentre.translate(
            side * faceW * (0.34 + (i % 3) * 0.14),
            faceH * (0.16 + (i % 2) * 0.09),
          ),
          faceW * 0.045,
          f,
        );
      }
    }
  }

  void _cap(
    Canvas canvas,
    Offset c,
    double fw,
    double fh,
    double drop,
    Paint paint,
  ) {
    final path = Path()
      ..moveTo(c.dx - fw * 1.02, c.dy - fh * (drop - 0.35))
      ..quadraticBezierTo(
        c.dx - fw * 1.05,
        c.dy - fh * 1.16,
        c.dx,
        c.dy - fh * 1.12,
      )
      ..quadraticBezierTo(
        c.dx + fw * 1.05,
        c.dy - fh * 1.16,
        c.dx + fw * 1.02,
        c.dy - fh * (drop - 0.35),
      )
      ..quadraticBezierTo(
        c.dx + fw * 0.6,
        c.dy - fh * (drop + 0.02),
        c.dx,
        c.dy - fh * (drop - 0.06),
      )
      ..quadraticBezierTo(
        c.dx - fw * 0.6,
        c.dy - fh * (drop + 0.02),
        c.dx - fw * 1.02,
        c.dy - fh * (drop - 0.35),
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  static Color _shade(Color base, double factor) {
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness * factor).clamp(0.0, 1.0))
        .toColor();
  }

  // Compare the SEED, not the traits. `_Traits` has no value equality, so
  // comparing instances is identity comparison — always unequal, repainting
  // every single frame for a picture that by definition never changes.
  @override
  bool shouldRepaint(_PortraitPainter old) => old.seed != seed;
}
