import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:flutter/material.dart';

/// Big, bold, kinetic karaoke (the Speak feature). Renders the whole script
/// large; the word being spoken pops — scaled up, in the accent colour, with
/// a soft glow — while spoken words recede and upcoming ones stay faint. Pure
/// from ([words], [position]); the screen feeds [position] from the audio
/// player's stream, so the highlight tracks the voice.
class KaraokeView extends StatelessWidget {
  const KaraokeView({
    required this.words,
    required this.position,
    this.accent,
    super.key,
  });

  final List<SpokenWord> words;
  final Duration position;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = this.accent ?? theme.colorScheme.primary;
    final current = currentWordIndex(words, position);
    // Announce the whole script as ONE label and hide the per-word nodes from
    // assistive tech — otherwise a screen reader reads each word in isolation,
    // fighting the audio that's reading the same text aloud.
    return Semantics(
      label: words.map((w) => w.text).join(' '),
      container: true,
      child: ExcludeSemantics(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 18,
              children: [
                for (var i = 0; i < words.length; i++)
                  _KaraokeWord(
                    text: words[i].text,
                    phase: i == current
                        ? _Phase.active
                        : (i < current ? _Phase.spoken : _Phase.upcoming),
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

enum _Phase { spoken, active, upcoming }

class _KaraokeWord extends StatelessWidget {
  const _KaraokeWord({
    required this.text,
    required this.phase,
    required this.accent,
  });

  final String text;
  final _Phase phase;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final active = phase == _Phase.active;
    final spoken = phase == _Phase.spoken;
    // Upcoming words stay quiet but must remain LEGIBLE — emerging readers
    // follow along here. 0.55 over the near-black background clears WCAG AA;
    // anything lower (we started at 0.28) is unreadable for that audience.
    final color = active
        ? accent
        : spoken
            ? Colors.white.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.55);
    return AnimatedScale(
      scale: active ? 1.18 : 1.0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 200),
        style: TextStyle(
          fontSize: 46,
          height: 1.05,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
          color: color,
          shadows: active
              ? [
                  Shadow(
                    blurRadius: 28,
                    color: accent.withValues(alpha: 0.55),
                  ),
                ]
              : null,
        ),
        child: Text(text),
      ),
    );
  }
}
