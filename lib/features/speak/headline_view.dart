import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The bold-statement poster: the current short phrase set in BLACK CAPS,
/// stacked one word per line, flush left, tight-leading, scaled to fill the
/// frame. The Spotify-Wrapped / A24 look — best in the condensed face (Bold).
/// High contrast: the spoken word is full white, the rest recede hard.
class HeadlineView extends StatelessWidget {
  const HeadlineView({
    required this.lines,
    required this.position,
    required this.type,
    required this.accent,
    super.key,
  });

  final List<SpokenLine> lines;
  final Duration position;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final idx = lineIndexAt(lines, position);
    final child = (idx < 0 || lines.isEmpty)
        ? const SizedBox.shrink(key: ValueKey('headline-lead-in'))
        : _HeadlineLine(
            key: ValueKey('headline-$idx'),
            line: lines[idx],
            activeWord: currentWordIndex(lines[idx].words, position),
            type: type,
          );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(-0.06, 0),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _HeadlineLine extends StatelessWidget {
  const _HeadlineLine({
    required this.line,
    required this.activeWord,
    required this.type,
    super.key,
  });

  final SpokenLine line;
  final int activeWord;
  final SpeakType type;

  @override
  Widget build(BuildContext context) {
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(28, 80, 28, 100 + viewPad),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < line.words.length; i++)
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutQuart,
                  style: TextStyle(
                    fontFamily: type.family,
                    fontSize: 92,
                    height: 0.92,
                    letterSpacing: -1.5,
                    color: Colors.white.withValues(
                      alpha: i == activeWord ? 1 : 0.3,
                    ),
                    fontVariations: type.axesAt(type.activeWeight),
                  ),
                  child: Text(line.words[i].text.toUpperCase()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
