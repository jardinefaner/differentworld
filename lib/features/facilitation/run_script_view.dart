import 'package:differentworld/features/facilitation/room_beat.dart';
import 'package:differentworld/features/facilitation/steps.dart';
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
        // Not FitOrScroll here: its Align(center) collapses the Expanded, so
        // the whole script rendered as a small block floating mid-screen with
        // Next stranded beside it. This is the fill-or-scroll recipe without
        // the centring — the column FILLS the viewport (line in the middle,
        // controls on the floor) and only scrolls when a large text setting
        // makes it taller than the screen.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 32,
              ),
              // IntrinsicHeight is what lets the Expanded below resolve inside a
              // scroll view. Without it the flex child gets an unbounded main
              // axis, the render tree throws, and the plate comes out BLANK —
              // which is how this was caught.
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color: quiet,
                          ), // raw-canvas
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${at.human} of ${at.total}',
                      style:
                          Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color: quiet,
                          ), // raw-canvas
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The line the ROOM reads, so it is display-sized and
                            // scales with the reader's text setting.
                            Text(
                              beat.line,
                              style: Theme.of(context).textTheme.displaySmall
                                  ?.copyWith(
                                    color: onLine, // raw-canvas
                                    fontWeight: FontWeight.w400,
                                  ),
                            ),
                            if (beat.detail case final d?) ...[
                              const SizedBox(height: 12),
                              Text(
                                d,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: quiet), // raw-canvas
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
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
                            icon: Icon(
                              last ? Icons.play_arrow : Icons.arrow_forward,
                            ),
                            label: Text(last ? 'Start' : 'Next'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
