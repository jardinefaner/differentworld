import 'package:differentworld/features/speak/speak_view_base.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// Scale contrast / break-the-grid: the word being read is blown up huge and
/// bleeds off the screen edges (clipped), while the rest of the phrase sits
/// small above and below it. Maximalist, editorial. Best in the condensed
/// face (Bold).
class OversizedView extends SpeakLinesView {
  const OversizedView({
    required super.lines,
    required super.position,
    required super.type,
    required super.accent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final idx = lineIndexAt(lines, position);
    if (idx < 0 || lines.isEmpty) return const SizedBox.shrink();
    final line = lines[idx];
    final active = currentWordIndex(line.words, position).clamp(
      0,
      line.words.length - 1,
    );
    final before = line.words.sublist(0, active).map((w) => w.text).join(' ');
    final after = line.words.sublist(active + 1).map((w) => w.text).join(' ');
    final viewPad = MediaQuery.viewPaddingOf(context).bottom;

    final small = TextStyle(
      fontFamily: type.family,
      fontSize: 26,
      letterSpacing: -0.5,
      color: Colors.white.withValues(alpha: 0.45),
      fontVariations: type.axesAt(type.restWeight),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 80, 24, 100 + viewPad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (before.isNotEmpty) Text(before, style: small),
          const SizedBox(height: 6),
          // The huge word — left-aligned, allowed to overflow the right edge.
          ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  line.words[active].text.toUpperCase(),
                  key: ValueKey('huge-$idx-$active'),
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontFamily: type.family,
                    fontSize: 188,
                    height: 0.9,
                    letterSpacing: -4,
                    color: Colors.white,
                    fontVariations: type.axesAt(type.activeWeight),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (after.isNotEmpty) Text(after, style: small),
        ],
      ),
    );
  }
}
