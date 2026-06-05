import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:flutter/material.dart';

/// Lines accumulate into the full passage — the current line brightest at the
/// bottom, older lines receding upward and dimming. You watch the quote build,
/// teleprompter-style. (Scroll up to revisit earlier lines.)
class StackView extends StatelessWidget {
  const StackView({
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
    final current = lineIndexAt(lines, position);
    if (current < 0 || lines.isEmpty) return const SizedBox.shrink();
    final shown = current + 1;
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;
    // reverse: true pins the newest line to the bottom and lets older lines
    // grow upward + scroll off the top — no scroll controller needed.
    return ListView.builder(
      reverse: true,
      padding: EdgeInsets.fromLTRB(28, 96, 28, 40 + bottomSafe),
      itemCount: shown,
      itemBuilder: (context, i) {
        final lineIdx = current - i; // i == 0 → current line (bottom)
        final isCurrent = i == 0;
        // Older lines recede; floor kept legible.
        final alpha = isCurrent
            ? 1.0
            : (0.52 - (i - 1) * 0.12).clamp(0.16, 0.52);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            style: TextStyle(
              fontFamily: type.family,
              fontSize: isCurrent ? 40 : 33,
              height: 1.12,
              letterSpacing: type.letterSpacing,
              color: Colors.white.withValues(alpha: alpha),
              fontVariations: type.axesAt(
                isCurrent ? type.activeWeight : type.restWeight,
              ),
              shadows: isCurrent
                  ? [
                      Shadow(
                        color: accent.withValues(alpha: 0.4),
                        blurRadius: 22,
                      ),
                    ]
                  : null,
            ),
            child: Text(lines[lineIdx].text, textAlign: TextAlign.center),
          ),
        );
      },
    );
  }
}
