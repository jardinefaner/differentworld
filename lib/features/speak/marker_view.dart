import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// Bold type, and the word being read gets a fat highlighter swipe behind it in
/// the voice's colour — dark ink on the swipe, white everywhere else. The
/// "highlighted text" social/editorial look. Shows the current phrase.
class MarkerView extends StatelessWidget {
  const MarkerView({
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
        ? const SizedBox.shrink(key: ValueKey('marker-lead-in'))
        : _MarkerLine(
            key: ValueKey('marker-$idx'),
            line: lines[idx],
            activeWord: currentWordIndex(lines[idx].words, position),
            type: type,
            accent: accent,
          );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOut,
      child: child,
    );
  }
}

class _MarkerLine extends StatelessWidget {
  const _MarkerLine({
    required this.line,
    required this.activeWord,
    required this.type,
    required this.accent,
    super.key,
  });

  final SpokenLine line;
  final int activeWord;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(28, 80, 28, 100 + viewPad),
        child: FittedBox(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                for (var i = 0; i < line.words.length; i++)
                  _MarkerWord(
                    text: line.words[i].text,
                    active: i == activeWord,
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

class _MarkerWord extends StatelessWidget {
  const _MarkerWord({
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
    final style = TextStyle(
      fontFamily: type.family,
      fontSize: 60,
      height: 1.04,
      letterSpacing: -1,
      fontVariations: type.axesAt(type.activeWeight),
      // Dark ink on the bright swipe; white off it.
      color: active ? const Color(0xFF101216) : Colors.white,
    );
    final label = Text(text, style: style);
    if (!active) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: label,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: label,
    );
  }
}
