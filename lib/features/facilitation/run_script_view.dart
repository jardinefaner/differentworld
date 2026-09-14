import 'package:differentworld/features/facilitation/room_beat.dart';
import 'package:differentworld/features/facilitation/steps.dart';
import 'package:differentworld/shared/widgets/fit_or_scroll.dart';
import 'package:flutter/material.dart';

/// The run-script on screen: one beat at a time, advanced by one tap.
///
/// **The whole design goal is that the adult can know nothing.** A substitute
/// holding a room they did not plan for should be able to start any activity
/// by finding Next — the children are told what to do by the screen, in their
/// own words, and the adult reads the same line they do. Nothing here is a
/// manual, a tooltip, or a panel: those all require the adult to read ahead of
/// the room, which is the thing there is no time for.
///
/// It is a RAW CANVAS by the theme contract (docs/THEME_ADHERENCE.md) — the
/// same class as a projection stage, because that is what it is. The colours
/// come from the game's own vibe so the script and the board it introduces
/// read as one thing rather than a system screen bolted in front of a game.
class RunScriptView extends StatelessWidget {
  const RunScriptView({
    required this.script,
    required this.index,
    required this.title,
    required this.surface,
    required this.onLine,
    this.onNext,
    this.onBack,
    super.key,
  });

  final RunScript script;

  /// Which beat, from the WIRE (run_script_wire.dart) — never local state, so
  /// the phone and the room screen are never on different beats.
  final int index;

  /// The game's name, shown small — the room's anchor if someone looks up
  /// halfway through.
  final String title;

  /// The stage colour this script introduces.
  final Color surface;

  /// Foreground picked for contrast against [surface] by the caller, which
  /// knows the vibe; content-driven colours have no theme to ask.
  final Color onLine;

  /// Sending the intents. **Null on a cast receiver**, which is a display and
  /// must never own the cursor — two devices that can both advance the rules
  /// is two devices that disagree about which rule the room just heard.
  final VoidCallback? onNext;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final at = Steps(
      index: index.clamp(0, script.length - 1),
      total: script.length,
    );
    final beat = script[at.index];
    final quiet = onLine.withValues(alpha: 0.72);
    final last = at.index == at.total - 1;
    return ColoredBox(
      color: surface,
      child: SafeArea(
        // The controls sit OUTSIDE the scroll view, pinned to the floor.
        //
        // They used to ride inside it, and at 200% text the line grew tall
        // enough to push Next to y=940 on a 900dp screen — off the bottom,
        // reachable only by scrolling a screen that gives no sign it scrolls.
        // The one control the whole feature depends on was the one a large
        // text setting hid. Caught by the control-bar overflow test.
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              // Centred while it fits — a room reads this from across the
              // floor, and a line pinned to the ceiling is harder to find
              // than one in the middle. It scrolls only when a large text
              // setting makes it taller than the space, and the controls are
              // outside this box either way.
              child: FitOrScroll(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: quiet),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${at.human} of ${at.total}',
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: quiet),
                    ),
                    const SizedBox(height: 32),
                    // The line the ROOM reads, so it is display-sized and
                    // scales with the reader's text setting.
                    Text(
                      beat.line,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: onLine,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    if (beat.detail case final d?) ...[
                      const SizedBox(height: 12),
                      Text(
                        d,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: quiet),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Row(
                children: [
                  if (at.index > 0 && onBack != null)
                    TextButton(
                      onPressed: onBack,
                      style: TextButton.styleFrom(foregroundColor: quiet),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (onNext != null)
                    FilledButton.icon(
                      onPressed: onNext,
                      icon: Icon(last ? Icons.play_arrow : Icons.arrow_forward),
                      label: Text(last ? 'Start' : 'Next'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
