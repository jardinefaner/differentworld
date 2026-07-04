import 'dart:math' as math;

import 'package:differentworld/features/speak/speak_view_base.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The whole text in a fixed grid — one word per cell, each scaled to fill its
/// cell. The grid (cols ≈ √n) is computed once; the spoken word's cell lights
/// up in place. Architectural and very designed; the cells never move.
class WordGridView extends SpeakWordsView {
  const WordGridView({
    required super.words,
    required super.position,
    required super.type,
    required super.accent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const SizedBox.shrink();
    final active = currentWordIndex(words, position);
    final n = words.length;
    final cols = math.max(1, math.sqrt(n).ceil());
    final rows = (n / cols).ceil();
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 88, 12, 12 + viewPad),
      child: Column(
        children: [
          for (var r = 0; r < rows; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < cols; c++)
                    Expanded(
                      child: (r * cols + c) >= n
                          ? const SizedBox.shrink()
                          : _GridCell(
                              text: words[r * cols + c].text,
                              active: (r * cols + c) == active,
                              type: type,
                              accent: accent,
                            ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.text,
    required this.active,
    required this.type,
    required this.accent,
  });

  final String text;
  final bool active;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: FittedBox(
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutQuart,
          // Fixed weight (no change on active → the cell content never
          // rescales): only colour + glow move.
          style: TextStyle(
            fontFamily: type.family,
            fontSize: 80,
            height: 1,
            letterSpacing: type.letterSpacing,
            color: Colors.white.withValues(alpha: active ? 1 : 0.5),
            fontVariations: type.axesAt(type.activeWeight),
            shadows: active
                ? [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 28)]
                : null,
          ),
          child: Text(text),
        ),
      ),
    );
  }
}
