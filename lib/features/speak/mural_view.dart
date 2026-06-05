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
///
/// Stateful so the seeded layout is computed ONCE per text (not per word every
/// flip) — only the active highlight changes between flips.
class MuralView extends StatefulWidget {
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
  State<MuralView> createState() => _MuralViewState();
}

class _MuralViewState extends State<MuralView> {
  // "Some big, some super big" — a wide fixed pool of relative sizes.
  static const List<double> _sizes = [30, 44, 62, 92];

  late List<({double size, bool heavy})> _cells = _compute(widget.words);

  @override
  void didUpdateWidget(MuralView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only the words drive the layout; recompute when they actually change.
    if (!identical(widget.words, oldWidget.words)) {
      _cells = _compute(widget.words);
    }
  }

  List<({double size, bool heavy})> _compute(List<SpokenWord> words) {
    final cells = <({double size, bool heavy})>[];
    for (var i = 0; i < words.length; i++) {
      final rnd = math.Random(i * 131 + 17);
      // Fixed size (seeded) biased up by emphasis.
      final size =
          _sizes[rnd.nextInt(_sizes.length)] *
          (1 + wordEmphasis(words[i].text) * 0.45);
      cells.add((size: size, heavy: rnd.nextBool()));
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) return const SizedBox.shrink();
    final active = currentWordIndex(widget.words, widget.position);
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
                for (var i = 0; i < widget.words.length; i++)
                  _MuralWord(
                    text: widget.words[i].text,
                    cell: _cells[i],
                    active: i == active,
                    spoken: i < active,
                    type: widget.type,
                    accent: widget.accent,
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
    required this.cell,
    required this.active,
    required this.spoken,
    required this.type,
    required this.accent,
  });

  final String text;
  final ({double size, bool heavy}) cell;
  final bool active;
  final bool spoken;
  final SpeakType type;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Fixed weight (seeded; NOT changed on active — a heavier glyph is wider
    // and would shift the wall). Only colour + glow move.
    final weight = cell.heavy ? type.activeWeight : type.restWeight;
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
        fontSize: cell.size,
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
