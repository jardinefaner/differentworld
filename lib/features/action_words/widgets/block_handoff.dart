import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/action_words/reveal_overlay.dart';
import 'package:differentworld/features/activity_runtime/activity_runners.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The calm "what's next" handoff shown when a schedule-aware run (`/play-today`)
/// ENDS — the connective tissue that carries a teacher to the NEXT block
/// instead of dropping them on a dead clock face (docs/VISION.md "the day, on
/// rails" — and the law that the rails never just *stop*).
///
/// It reads the cohort that's live RIGHT NOW (across the viewer's rooms) and
/// that cohort's next planned block. Two shapes:
///   • there IS a next block → "Next: {block} at {time}" + **[Run it →]**
///     (launches the next block's run the SAME way the schedule's Run button
///     does — the activity's runner, else the generic teaching arc) + a
///     **[Back to today]** exit.
///   • nothing left on the day → "That's the last block." + **[Start the
///     reveal →]** (the closing ceremony) + the same **[Back to today]**.
///
/// "Always an exit, never a trap": [Back to today] is ALWAYS present and goes
/// to the home cockpit, no matter how the run was entered. It sits over the
/// still-mounted present surface (BeatPresenter's `onFinished` overlay), so
/// launching the next run / the reveal re-enters cleanly and backing out
/// (the small dismiss affordance) returns to the run.
class BlockHandoff extends ConsumerWidget {
  const BlockHandoff({
    required this.justFinishedTitle,
    required this.accent,
    required this.onDismiss,
    super.key,
  });

  /// The block/activity the teacher just finished — named back to them so the
  /// handoff reads as a close, not a cold prompt ("That's {Forest Fort}.").
  final String justFinishedTitle;

  /// The room's colour — tints the dark surface, matching the run it covers.
  final Color accent;

  /// Close the handoff and return to the (still-running) present surface.
  /// Wired to BeatPresenter's `dismiss` so backing out re-arms immersive.
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The cohort live across the viewer's rooms IS the one being run — the day
    // run isn't bound to a single cohort, so this is how we know whose
    // schedule to read next from. Null (run started at a gap) → treat as "no
    // next block" and offer the reveal.
    final live = ref.watch(liveBlockProvider);
    final next = live == null
        ? null
        : ref.watch(nextScheduledBlockProvider(live.groupId));

    // Always-dark surface — this covers the immersive run, so it stays in the
    // same visual language (the dark stage is a raw canvas; see
    // THEME_ADHERENCE). Text reads on the dark gradient; the accent is a pale
    // AA-safe tint for captions.
    return Theme(
      data: buildDarkTheme(),
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(accent.withValues(alpha: 0.5), Colors.black),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Back-to-the-run affordance, top-left — so the handoff isn't
                // a one-way door if the teacher wanted one more pass.
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    tooltip: 'Back to the run',
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white70,
                    ),
                    onPressed: onDismiss,
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      child: next == null
                          ? _LastBlock(accent: accent)
                          : _NextUp(
                              justFinishedTitle: justFinishedTitle,
                              next: next,
                              accent: accent,
                            ),
                    ),
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

/// There's a next block — name what just finished, show what's next + when,
/// and the two moves (Run it / Back to today). Stateful for a one-shot launch
/// guard: a fat-finger double-tap on "Run it" would otherwise fire two
/// `pushReplacement`s (runner twice, or runner + arc) before the first frame.
class _NextUp extends StatefulWidget {
  const _NextUp({
    required this.justFinishedTitle,
    required this.next,
    required this.accent,
  });

  final String justFinishedTitle;
  final NextBlock next;
  final Color accent;

  @override
  State<_NextUp> createState() => _NextUpState();
}

class _NextUpState extends State<_NextUp> {
  /// Held from the first "Run it" tap so a second can't push a second route.
  bool _launching = false;

  @override
  Widget build(BuildContext context) {
    final captionColor = AppColors.readableOnDark(widget.accent);
    final next = widget.next;
    final finished = widget.justFinishedTitle.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (finished.isNotEmpty) ...[
          Text(
            "That's “$finished”.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 28),
        ],
        Text(
          'NEXT · ${timeOfDay(next.startAt)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: captionColor,
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          next.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 36),
        FilledButton.icon(
          onPressed: _launching ? null : _runNext,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Run it'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => context.go('/'),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: Colors.white70,
          ),
          child: const Text('Back to today'),
        ),
      ],
    );
  }

  /// Launch the next block's run — the activity's chosen full-screen runner if
  /// it names one (seeding Photo Studio's prompt with the topic), else the
  /// generic teaching arc. Mirrors the schedule's `_BlockTile` Run button so a
  /// block runs identically whether launched from the grid or this handoff.
  /// `pushReplacement` so the finished run leaves the stack — the new run
  /// becomes the present surface, and its own end raises the next handoff.
  void _runNext() {
    if (_launching) return;
    setState(() => _launching = true);
    unawaited(HapticFeedback.selectionClick());
    final next = widget.next;
    final runner = runnerForSlug(next.runnerSlug);
    if (runner != null) {
      final dest = runner.takesPrompt
          ? Uri(
              path: runner.route,
              queryParameters: {'prompt': next.runTopic},
            ).toString()
          : runner.route;
      context.pushReplacement(dest);
    } else {
      context.pushReplacement('/arc', extra: next.runTopic);
    }
  }
}

/// Nothing left on the day — the run's last beat IS the day's close. Offer the
/// closing reveal (the ceremony the close beat hands off to) and the exit.
/// Stateful for the same one-shot guard as [_NextUp] (a double-tap on "Start
/// the reveal" would push the ceremony twice).
class _LastBlock extends ConsumerStatefulWidget {
  const _LastBlock({required this.accent});

  final Color accent;

  @override
  ConsumerState<_LastBlock> createState() => _LastBlockState();
}

class _LastBlockState extends ConsumerState<_LastBlock> {
  bool _launching = false;

  @override
  Widget build(BuildContext context) {
    final captionColor = AppColors.readableOnDark(widget.accent);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'THE DAY',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: captionColor,
            fontSize: 14,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          "That's the last block.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Gather back and name who everyone was today.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 36),
        FilledButton.icon(
          onPressed: _launching ? null : _startReveal,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Start the reveal'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: 10),
        // After the day's run ends, the next real move is dismissal — point the
        // teacher at the pickup board so the run leads INTO the hand-off
        // instead of dead-ending on the ceremony (docs/WORKFLOWS.md "the
        // closing chain": reveal → pickup → send). `go` (not push) so the
        // immersive run leaves the stack as we cross into the dismissal board.
        FilledButton.tonalIcon(
          onPressed: () {
            unawaited(HapticFeedback.selectionClick());
            context.go('/pickup');
          },
          icon: const Icon(Icons.directions_walk),
          label: const Text('Go to pickup'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => context.go('/'),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor: Colors.white70,
          ),
          child: const Text('Back to today'),
        ),
      ],
    );
  }

  /// Push the closing ceremony OVER the handoff (the handoff persists beneath,
  /// so when the reveal ends the teacher lands back on "what's next" with the
  /// exit still there — never stranded). The reveal owns its own immersive
  /// mode; we don't dismiss the handoff first.
  void _startReveal() {
    if (_launching) return;
    setState(() => _launching = true);
    unawaited(HapticFeedback.selectionClick());
    unawaited(revealAllPicksToday(context, ref));
    // The reveal is a route over us; once it pops we're back on the handoff.
    // Re-arm the button so the teacher can run the ceremony again if they want.
    if (mounted) setState(() => _launching = false);
  }
}
