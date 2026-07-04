import 'package:differentworld/features/speak/speak_view_base.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// One giant word at a time, scaled to fill the frame, punching in on the beat.
/// Pauses + periods become the rhythm (the word simply holds). High-impact —
/// the "full-screen typography" mode.
class OneBigWordView extends SpeakWordsView {
  const OneBigWordView({
    required super.words,
    required super.position,
    required super.type,
    required super.accent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final i = currentWordIndex(words, position);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    final child = (i < 0 || words.isEmpty)
        ? const SizedBox.shrink(key: ValueKey('obw-lead-in'))
        : _BigWord(
            key: ValueKey('obw-$i'),
            text: words[i].text,
            type: type,
            accent: accent,
          );

    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + bottomSafe),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) {
            // Punch in: scale overshoots (easeOutBack) while the fade stays a
            // clean 0→1 (easeOut) — keeps opacity in range, scale does the pop.
            final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
            final scale = Tween<double>(begin: 0.84, end: 1).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            );
            return FadeTransition(
              opacity: fade,
              child: ScaleTransition(scale: scale, child: child),
            );
          },
          child: child,
        ),
      ),
    );
  }
}

class _BigWord extends StatelessWidget {
  const _BigWord({
    required this.text,
    required this.type,
    required this.accent,
    super.key,
  });

  final String text;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // BoxFit.contain scales the word UP to fill the frame (and down for long
    // words) — the base size is nominal; the fit decides the rendered size.
    return FittedBox(
      // FittedBox defaults to BoxFit.contain — scales the word up to fill.
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontFamily: type.family,
          fontSize: 200,
          height: 1,
          letterSpacing: type.letterSpacing,
          color: Colors.white,
          fontVariations: type.axesAt(type.activeWeight),
          shadows: [
            Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 40),
          ],
        ),
      ),
    );
  }
}
