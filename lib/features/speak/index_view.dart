import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The text as a styled index — one phrase per numbered row; the spoken row
/// lights up (brighter + heavier + glowing). An editorial "contents page."
/// Rows are full-width and stacked, so a row's emphasis never moves the others.
class IndexView extends StatelessWidget {
  const IndexView({
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
    if (lines.isEmpty) return const SizedBox.shrink();
    final active = lineIndexAt(lines, position);
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(28, 96, 28, 40 + viewPad),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < lines.length; i++)
                _IndexRow(
                  number: i + 1,
                  text: lines[i].text,
                  active: i == active,
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

class _IndexRow extends StatelessWidget {
  const _IndexRow({
    required this.number,
    required this.text,
    required this.active,
    required this.type,
    required this.accent,
  });

  final int number;
  final String text;
  final bool active;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              number.toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: type.family,
                fontSize: 18,
                color: active ? accent : Colors.white.withValues(alpha: 0.35),
                fontVariations: type.axesAt(type.restWeight),
              ),
            ),
          ),
          Expanded(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutQuart,
              style: TextStyle(
                fontFamily: type.family,
                fontSize: 30,
                height: 1.25,
                letterSpacing: type.letterSpacing,
                color: Colors.white.withValues(alpha: active ? 1 : 0.45),
                fontVariations: type.axesAt(
                  active ? type.activeWeight : type.restWeight,
                ),
                shadows: active
                    ? [
                        Shadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 22,
                        ),
                      ]
                    : null,
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}
