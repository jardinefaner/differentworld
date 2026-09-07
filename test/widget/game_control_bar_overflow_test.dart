// The game control bar at the 200% text floor, on BOTH beats and BOTH
// layouts. This lives outside the gallery because the gallery never renders
// the end-of-round beat at the wide breakpoint — which is how the wide bar
// carried a 280dp overflow on "Round complete!" unnoticed. Adding the
// "Add ours" door widened it to 542dp and made it worth finding.
//
// Anything new in either control surface has to keep these at zero.

import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/riddles_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pump the runner at [size] and 200% text, then return the overflow
  /// messages raised while driving the round to its end.
  Future<List<String>> overflowsDrivingToDone(
    WidgetTester tester,
    Size size,
  ) async {
    final errors = <String>[];
    final prior = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: GameRunner(def: RiddlesGame()),
          ),
        ),
      ),
    );
    await tester.pump();

    for (var i = 0; i < 40; i++) {
      final reveal = find.widgetWithText(FilledButton, 'Reveal');
      if (reveal.evaluate().isNotEmpty) {
        await tester.tap(reveal);
        await tester.pump(const Duration(milliseconds: 400));
      }
      final next = find.widgetWithText(FilledButton, 'Next');
      if (next.evaluate().isEmpty) break;
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(seconds: 1));

    // Restore BEFORE asserting: an expect() while onError is still overridden
    // trips the binding's own "you never gave it back" assertion, which then
    // masks the real result.
    final reached = find.text('Round complete!').evaluate().isNotEmpty;
    FlutterError.onError = prior;
    expect(
      reached,
      isTrue,
      reason: 'the probe must actually reach the beat it claims to check',
    );
    return errors.where((e) => e.contains('overflow')).toList();
  }

  testWidgets('wide control bar survives 200% text through to the wrap beat', (
    tester,
  ) async {
    // 720dp is the wide breakpoint floor — the tightest width that gets the
    // horizontal bar rather than the phone panel.
    expect(
      await overflowsDrivingToDone(tester, const Size(720, 1200)),
      isEmpty,
    );
  });

  testWidgets('the phone stage does not lose more room than it already has', (
    tester,
  ) async {
    // NOT zero, and deliberately not pretending to be. At 200% the game STAGE
    // (not the panel) is taller than the room the controls leave it — a
    // pre-existing defect measured at 228dp on main. Trimming the panel's
    // redundant caption bought most of it back; closing the rest needs
    // stage-level layout changes across 41 games, which is its own wave.
    //
    // This is a RATCHET: it fails if the controls grow again. Lower the
    // budget when the stage is fixed; never raise it.
    const budget = 80;
    final overflows = await overflowsDrivingToDone(
      tester,
      const Size(400, 900),
    );
    for (final o in overflows) {
      final px = int.parse(RegExp(r'(\d+) pixels').firstMatch(o)!.group(1)!);
      expect(
        px,
        lessThanOrEqualTo(budget),
        reason:
            'the phone controls grew — they now cost the stage $px dp '
            '(was 228 on main; budget $budget)',
      );
    }
  });
}
