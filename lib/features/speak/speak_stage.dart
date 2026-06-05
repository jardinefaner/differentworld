import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// The editorial Speak stage: one short line at a time, set large and centred.
/// The word being spoken swells in weight (variable font) and brightens; the
/// rest of the line stays quiet. When the voice moves to the next line, the
/// current line lifts and fades as the next settles up into its place.
///
/// Pure from ([lines], [position], [type]) — the host feeds [position] from a
/// per-frame ticker so flips land on the voice. Restraint is the brief: the
/// *setting* of the type is the show, not flashy motion.
class SpeakStage extends StatelessWidget {
  const SpeakStage({
    required this.lines,
    required this.position,
    required this.type,
    this.done = false,
    super.key,
  });

  final List<SpokenLine> lines;
  final Duration position;
  final SpeakType type;

  /// When playback has finished, the stage dims to signal "done" (the host
  /// overlays a tap-to-replay nudge).
  final bool done;

  /// Base size before fit-to-width scale-down. Large — short lines stay big;
  /// long lines scale to fit (and wrap to a second line if needed).
  static const double _baseSize = 84;

  @override
  Widget build(BuildContext context) {
    final index = lineIndexAt(lines, position);
    final Widget child;
    if (index < 0 || lines.isEmpty) {
      // Lead-in silence — an empty stage that the first line rises into.
      child = const SizedBox.shrink(key: ValueKey('speak-stage-lead-in'));
    } else {
      final line = lines[index];
      child = _StageLine(
        // Key by index so AnimatedSwitcher animates the swap, not just a
        // content rebuild.
        key: ValueKey('speak-line-$index'),
        line: line,
        activeWord: currentWordIndex(line.words, position),
        type: type,
        baseSize: _baseSize,
      );
    }

    // Respect the home-indicator zone at the bottom (the stage is full-bleed,
    // so nothing else reserves it).
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    return AnimatedOpacity(
      opacity: done ? 0.5 : 1,
      duration: const Duration(milliseconds: 400),
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(32, 24, 32, 24 + bottomSafe),
          child: AnimatedSwitcher(
            // Short relative to a line's on-screen life (~1.5–2.5s) so the stage
            // is mostly STILL — editorial reads as calm, not in constant motion.
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // Keep both the outgoing + incoming line centred and stacked.
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.center,
              children: [...previousChildren, ?currentChild],
            ),
            transitionBuilder: (child, anim) {
              // Incoming: rises from below + fades in. Outgoing (anim in reverse)
              // sinks + fades — a calm vertical dissolve. 0.18 of the line's own
              // height is enough travel to read as a deliberate gesture at 84sp.
              final slide = Tween<Offset>(
                begin: const Offset(0, 0.18),
                end: Offset.zero,
              ).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Where a word sits in the line's timeline — drives its brightness so you can
/// feel the voice move THROUGH the line, not just land on one word.
enum _WordPhase { past, active, future }

class _StageLine extends StatelessWidget {
  const _StageLine({
    required this.line,
    required this.activeWord,
    required this.type,
    required this.baseSize,
    super.key,
  });

  final SpokenLine line;

  /// Index within `line.words` of the word being spoken, or -1.
  final int activeWord;
  final SpeakType type;
  final double baseSize;

  @override
  Widget build(BuildContext context) {
    // Fit-to-width: short lines stay at base size; long lines scale down (and
    // wrap to a second line at the 760 cap) rather than shrinking to nothing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 22,
          runSpacing: 4,
          children: [
            for (var i = 0; i < line.words.length; i++)
              _StageWord(
                text: line.words[i].text,
                phase: i == activeWord
                    ? _WordPhase.active
                    : (i < activeWord ? _WordPhase.past : _WordPhase.future),
                type: type,
                size: baseSize,
              ),
          ],
        ),
      ),
    );
  }
}

class _StageWord extends StatelessWidget {
  const _StageWord({
    required this.text,
    required this.phase,
    required this.type,
    required this.size,
  });

  final String text;
  final _WordPhase phase;
  final SpeakType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final active = phase == _WordPhase.active;
    final weight = active ? type.activeWeight : type.restWeight;
    // Past words recede further than not-yet-spoken ones — a gentle past →
    // present → future gradient. Floors kept legible (≥0.55 clears WCAG AA on
    // the near-black stage) so emerging readers can still follow the quiet
    // words; the active word still clearly dominates at 1.0 + the weight swell.
    final alpha = switch (phase) {
      _WordPhase.active => 1.0,
      _WordPhase.future => 0.68,
      _WordPhase.past => 0.55,
    };
    // ONE implicit animation per word: TextStyle.lerp interpolates BOTH the
    // weight axis (fontVariations) and the colour, so the swell + brightness
    // move together over one front-loaded curve. Monochrome on purpose —
    // weight carries the emphasis, no accent colour. Editorial restraint.
    return AnimatedDefaultTextStyle(
      duration: type.swellDuration,
      curve: Curves.easeOutQuart,
      style: TextStyle(
        fontFamily: type.family,
        fontSize: size,
        height: 1.06,
        letterSpacing: type.letterSpacing,
        color: Colors.white.withValues(alpha: alpha),
        fontVariations: type.axesAt(weight),
      ),
      child: Text(text),
    );
  }
}
