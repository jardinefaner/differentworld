import 'dart:math' as math;

import 'package:differentworld/features/speak/speak_view_base.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// Each phrase is a little editorial poster — words at varied sizes, weights,
/// and slight angles. The composition is STABLE per line (seeded, so it never
/// jitters); only the spoken word illuminates within it. Tasteful ransom-note.
class CollageView extends SpeakLinesView {
  const CollageView({
    required super.lines,
    required super.position,
    required super.type,
    required super.accent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final idx = lineIndexAt(lines, position);
    final child = (idx < 0 || lines.isEmpty)
        ? const SizedBox.shrink(key: ValueKey('collage-lead-in'))
        : _CollageLine(
            key: ValueKey('collage-$idx'),
            line: lines[idx],
            activeWord: currentWordIndex(lines[idx].words, position),
            seed: idx,
            type: type,
            accent: accent,
          );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _CollageLine extends StatefulWidget {
  const _CollageLine({
    required this.line,
    required this.activeWord,
    required this.seed,
    required this.type,
    required this.accent,
    super.key,
  });

  final SpokenLine line;
  final int activeWord;
  final int seed;
  final SpeakType type;
  final Color accent;

  @override
  State<_CollageLine> createState() => _CollageLineState();
}

class _CollageLineState extends State<_CollageLine> {
  static const List<double> _sizes = [30, 40, 52, 36, 46];

  // Computed ONCE — the line is keyed by index in the AnimatedSwitcher, so this
  // instance's line never changes; only `activeWord` does (re-read in build).
  late final List<({double size, double angle, bool heavy})> _cells =
      _compute();

  List<({double size, double angle, bool heavy})> _compute() {
    final rnd = math.Random(widget.seed * 7919 + 13);
    return [
      for (var i = 0; i < widget.line.words.length; i++)
        (
          size: _sizes[rnd.nextInt(_sizes.length)],
          angle: (rnd.nextDouble() - 0.5) * 0.16,
          heavy: rnd.nextBool(),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomSafe),
        child: FittedBox(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 2,
              children: [
                for (var i = 0; i < widget.line.words.length; i++)
                  Transform.rotate(
                    angle: _cells[i].angle,
                    child: _CollageWord(
                      text: widget.line.words[i].text,
                      size: _cells[i].size,
                      active: i == widget.activeWord,
                      heavy: _cells[i].heavy,
                      type: widget.type,
                      accent: widget.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollageWord extends StatelessWidget {
  const _CollageWord({
    required this.text,
    required this.size,
    required this.active,
    required this.heavy,
    required this.type,
    required this.accent,
  });

  final String text;
  final double size;
  final bool active;
  final bool heavy;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final weight = (active || heavy) ? type.activeWeight : type.restWeight;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutQuart,
      style: TextStyle(
        fontFamily: type.family,
        // Auto-emphasis biases the seeded size — emphasised words run bigger.
        fontSize: size * (1 + wordEmphasis(text) * 0.2),
        height: 1.04,
        letterSpacing: type.letterSpacing,
        color: Colors.white.withValues(alpha: active ? 1 : 0.6),
        fontVariations: type.axesAt(weight),
        shadows: active
            ? [Shadow(color: accent.withValues(alpha: 0.55), blurRadius: 28)]
            : null,
      ),
      child: Text(text),
    );
  }
}
