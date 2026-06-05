import 'dart:math' as math;

import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The whole text as one fixed wall of type — words at varied sizes (some big,
/// some HUGE), packed and scaled to fill the screen. The layout is FIXED: a
/// word's size + weight depend only on the text + its index, never on
/// playback, so nothing ever reflows. The spoken word lights up in place
/// (brightness + glow only — no size/weight change, since a heavier glyph is
/// wider and would shift the wall). Where a word is, is where it stays.
class MuralView extends StatelessWidget {
  const MuralView({
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
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 84, 18, 18 + viewPad),
        // Scale the fixed wall to fill the frame (contain = as big as fits).
        child: FittedBox(
          child: ConstrainedBox(
            // Narrow-ish so the wall runs tall and fills a portrait screen.
            constraints: const BoxConstraints(maxWidth: 720),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 18,
              children: [
                for (var i = 0; i < words.length; i++)
                  _MuralWord(
                    text: words[i].text,
                    active: i == active,
                    spoken: i < active,
                    seed: i,
                    type: type,
                    accent: accent,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MuralWord extends StatelessWidget {
  const _MuralWord({
    required this.text,
    required this.active,
    required this.spoken,
    required this.seed,
    required this.type,
    required this.accent,
  });

  final String text;
  final bool active;
  final bool spoken;
  final int seed;
  final SpeakType type;
  final Color accent;

  // "Some big, some super big" — a wide fixed pool of relative sizes.
  static const List<double> _sizes = [30, 44, 62, 92];

  @override
  Widget build(BuildContext context) {
    final rnd = math.Random(seed * 131 + 17);
    // Fixed size (seeded) biased up by emphasis — stable per word, so no
    // reflow as the highlight moves.
    final size =
        _sizes[rnd.nextInt(_sizes.length)] * (1 + wordEmphasis(text) * 0.45);
    // Fixed weight per word (NOT changed on active — a heavier glyph is wider
    // and would shift the wall).
    final weight = rnd.nextBool() ? type.activeWeight : type.restWeight;
    // Lit word dominates; the dim wall stays legible (≥0.45).
    final alpha = active
        ? 1.0
        : spoken
        ? 0.5
        : 0.45;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutQuart,
      style: TextStyle(
        fontFamily: type.family,
        fontSize: size,
        height: 1,
        letterSpacing: type.letterSpacing,
        color: Colors.white.withValues(alpha: alpha),
        fontVariations: type.axesAt(weight),
        shadows: active
            ? [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 34)]
            : null,
      ),
      child: Text(text),
    );
  }
}
