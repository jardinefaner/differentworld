import 'package:differentworld/features/speak/speak_view_base.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// One word at a time, BLACK CAPS, filling the frame — and it SLAMS: each word
/// stamps in slightly oversized and settles hard + fast, then cuts to the next
/// on the beat. Lyric-video / hype energy. Best in the condensed face (Bold).
class SlamView extends SpeakWordsView {
  const SlamView({
    required super.words,
    required super.position,
    required super.type,
    required super.accent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final i = currentWordIndex(words, position);
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    final child = (i < 0 || words.isEmpty)
        ? const SizedBox.shrink(key: ValueKey('slam-lead-in'))
        : _SlamWord(
            key: ValueKey('slam-$i'),
            text: words[i].text.toUpperCase(),
            type: type,
          );
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 80, 22, 100 + viewPad),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 170),
          transitionBuilder: (child, anim) {
            // Stamp: comes in oversized + fades fast, settles hard.
            final scale = Tween<double>(begin: 1.22, end: 1).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            );
            return FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
              child: ScaleTransition(scale: scale, child: child),
            );
          },
          child: child,
        ),
      ),
    );
  }
}

class _SlamWord extends StatelessWidget {
  const _SlamWord({required this.text, required this.type, super.key});

  final String text;
  final SpeakType type;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontFamily: type.family,
          fontSize: 220,
          height: 1,
          letterSpacing: -2,
          color: Colors.white,
          fontVariations: type.axesAt(type.activeWeight),
        ),
      ),
    );
  }
}
