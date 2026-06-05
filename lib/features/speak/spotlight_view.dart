import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The whole passage sits dim as one block; the spoken word ignites in place —
/// bright, heavier, glowing in the voice's hue — then settles back as the
/// light moves on. Follow-the-light, and a strong reading aid (you keep the
/// full context in view).
class SpotlightView extends StatelessWidget {
  const SpotlightView({
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
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 96, 28, 40 + viewPad),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 13,
            runSpacing: 6,
            children: [
              for (var i = 0; i < words.length; i++)
                _SpotWord(
                  text: words[i].text,
                  active: i == active,
                  spoken: i < active,
                  type: type,
                  accent: accent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotWord extends StatelessWidget {
  const _SpotWord({
    required this.text,
    required this.active,
    required this.spoken,
    required this.type,
    required this.accent,
  });

  final String text;
  final bool active;
  final bool spoken;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // The lit word dominates at 1.0 + weight + glow; the dim context stays
    // legible (≥0.45) — read words a touch brighter than the not-yet-read.
    final alpha = active
        ? 1.0
        : spoken
        ? 0.5
        : 0.45;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutQuart,
      style: TextStyle(
        fontFamily: type.family,
        // Auto-emphasis: ALL-CAPS / long / "!" words read a touch larger.
        fontSize: 36 * (1 + wordEmphasis(text) * 0.16),
        height: 1.18,
        letterSpacing: type.letterSpacing,
        color: Colors.white.withValues(alpha: alpha),
        fontVariations: type.axesAt(
          active ? type.activeWeight : type.restWeight,
        ),
        shadows: active
            ? [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 30)]
            : null,
      ),
      child: Text(text),
    );
  }
}
