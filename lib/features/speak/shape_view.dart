import 'dart:math' as math;

import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The words arranged around a ring — a playful fixed shape. Each word sits at
/// a fixed angle, upright; the spoken one lights up in place (colour + glow
/// only, so nothing shifts). Best with shorter texts; good for the kids.
class ShapeView extends StatelessWidget {
  const ShapeView({
    required this.words,
    required this.position,
    required this.type,
    required this.accent,
    super.key,
  });

  final List<SpokenWord> words;
  final Duration position;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();
    final active = currentWordIndex(words, position);
    final n = words.length;
    // Shrink the type as the ring crowds.
    final fontSize = (40 - n).clamp(15, 34).toDouble();
    const radius = 0.82;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < n; i++)
            Align(
              // Start at the top (−π/2) and go clockwise.
              alignment: Alignment(
                radius * math.cos(-math.pi / 2 + i / n * 2 * math.pi),
                radius * math.sin(-math.pi / 2 + i / n * 2 * math.pi),
              ),
              child: _ShapeWord(
                text: words[i].text,
                active: i == active,
                size: fontSize,
                type: type,
                accent: accent,
              ),
            ),
        ],
      ),
    );
  }
}

class _ShapeWord extends StatelessWidget {
  const _ShapeWord({
    required this.text,
    required this.active,
    required this.size,
    required this.type,
    required this.accent,
  });

  final String text;
  final bool active;
  final double size;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutQuart,
      // Fixed size + weight (only colour + glow move) so the ring holds.
      style: TextStyle(
        fontFamily: type.family,
        fontSize: size,
        height: 1,
        letterSpacing: type.letterSpacing,
        color: Colors.white.withValues(alpha: active ? 1 : 0.5),
        fontVariations: type.axesAt(type.activeWeight),
        shadows: active
            ? [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 26)]
            : null,
      ),
      child: Text(text),
    );
  }
}
