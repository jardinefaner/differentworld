// GameView is the one thing that draws a game, so what it decides is what
// every surface shows. These pin the four audiences against the four ways a
// surface can be wrong: no beats, no Next, a secret on the room's screen, and
// a board that cannot be touched where it is the instrument.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_controller.dart';
import 'package:differentworld/features/games/game_fullscreen.dart';
import 'package:differentworld/features/games/game_view.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/connect_four_game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/shape_stage_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const four = ConnectFourGame();
  const charades = CharadesGame();

  Map<String, dynamic> briefingWire() =>
      RunScriptWire.seed(four, four.initialState(LocalContentBank.seeded()));

  Map<String, dynamic> boardWire() {
    var w = briefingWire();
    for (var i = 0; i < four.howToPlay.length; i++) {
      w = RunScriptWire.reduce(four, w, GameIntent.next, const {});
    }
    return w;
  }

  /// A board played to a win — Red drops four down column 0.
  Map<String, dynamic> endedWire() {
    var w = boardWire();
    for (var move = 0; move < 7; move++) {
      w = four.reduce(w, GameIntent.pick, {'cell': move.isEven ? 0 : 1});
    }
    return w;
  }

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: Scaffold(body: child)),
      ),
    );
    await tester.pump();
  }

  for (final audience in GameAudience.values) {
    testWidgets('$audience sees the beats while the room is being briefed', (
      tester,
    ) async {
      await pump(
        tester,
        GameView(
          def: four,
          wire: briefingWire(),
          audience: audience,
          send: audience.drives ? (_, [_ = const {}]) {} : null,
        ),
      );
      expect(
        find.text('We are playing Connect Four'),
        findsOneWidget,
        reason: '$audience drew the board over the rules',
      );
      expect(find.byType(ShapeStageView), findsNothing);
    });

    testWidgets('$audience offers Next only if it drives', (tester) async {
      await pump(
        tester,
        GameView(
          def: four,
          wire: briefingWire(),
          audience: audience,
          send: audience.drives ? (_, [_ = const {}]) {} : null,
        ),
      );
      final next = find.text('Next');
      if (audience.drives) {
        expect(
          next,
          findsOneWidget,
          reason: '$audience can move the room on and has no button',
        );
      } else {
        expect(
          next,
          findsNothing,
          reason: 'a display that can advance the rules is a second opinion',
        );
      }
    });
  }

  testWidgets('the room screen never shows the actor the word', (tester) async {
    final wire = charades.initialState(LocalContentBank.seeded());
    await pump(
      tester,
      GameView(def: charades, wire: wire, audience: GameAudience.room),
    );
    expect(find.textContaining("the room can't see this"), findsNothing);
  });

  testWidgets('a hand holding the phone IS shown the word', (tester) async {
    final wire = charades.initialState(LocalContentBank.seeded());
    await pump(
      tester,
      GameView(
        def: charades,
        wire: wire,
        audience: GameAudience.host,
        send: (_, [_ = const {}]) {},
      ),
    );
    expect(find.textContaining("the room can't see this"), findsOneWidget);
  });

  testWidgets('fullscreen shows the rules, not a board nobody was told about', (
    tester,
  ) async {
    // The fifth surface. It drew `buildStage` directly, so tapping Fullscreen
    // during a briefing showed the board — and for a classic there is no Next
    // in its verbs, so the room could not be moved on from there either.
    final controller = LocalGameController(
      initial: briefingWire(),
      reduce: (state, intent, args) =>
          RunScriptWire.reduce(four, state, intent, args),
    );
    addTearDown(controller.dispose);
    await pump(
      tester,
      GameFullscreenScreen<GridBoard>(def: four, controller: controller),
    );
    await tester.pump();
    expect(find.text('We are playing Connect Four'), findsOneWidget);
    expect(find.byType(ShapeStageView), findsNothing);

    // And Next here moves the same wire the room is reading.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('We are playing Connect Four'), findsNothing);
    expect(RunScriptWire.indexOf(controller.state), 1);
  });

  testWidgets('ownsStage is false while the rules are up', (tester) async {
    // The layout probe every surface uses. A briefing is nobody's instrument,
    // so a scaffold must not hand it the no-control-bar treatment.
    late bool duringBriefing;
    late bool duringPlay;
    await pump(
      tester,
      Builder(
        builder: (context) {
          duringBriefing = GameView.ownsStage(context, four, briefingWire());
          duringPlay = GameView.ownsStage(context, four, boardWire());
          return const SizedBox.shrink();
        },
      ),
    );
    expect(duringBriefing, isFalse);
    expect(duringPlay, isTrue, reason: 'a dealt board IS the instrument');
  });

  testWidgets('a finished round offers Play again wherever it is driven', (
    tester,
  ) async {
    // The ending used to be three shapes and two absences: the scaffold drew
    // one for board games and a different one inside each of its two control
    // bars, the cockpit drew none — so a cast round froze on its winning line
    // — and fullscreen offered a bare "Again" with no line to read.
    var again = 0;
    var done = 0;
    for (final audience in GameAudience.values) {
      await pump(
        tester,
        GameView(
          def: four,
          wire: endedWire(),
          audience: audience,
          send: audience.drives
              ? (i, [_ = const {}]) {
                  if (i == GameIntent.reset) again++;
                }
              : null,
          onDone: audience.drives ? () => done++ : null,
        ),
      );
      final wrap = find.byKey(const ValueKey('round-wrap'));
      if (!audience.drives) {
        expect(
          wrap,
          findsNothing,
          reason: 'a television has no hands — the phone holds the verbs',
        );
        continue;
      }
      expect(wrap, findsOneWidget, reason: '$audience ends with no way on');
      expect(
        find.textContaining('wins'),
        findsWidgets,
        reason: '$audience ends without saying what happened',
      );
      await tester.tap(find.byKey(const ValueKey('round-wrap-again')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('round-wrap-done')));
      await tester.pump();
    }
    expect(again, 3, reason: 'host, remote and presenter each played again');
    expect(done, 3);
  });

  testWidgets('a surface with nowhere to go drops Done, not the whole beat', (
    tester,
  ) async {
    await pump(
      tester,
      GameView(
        def: four,
        wire: endedWire(),
        audience: GameAudience.presenter,
        send: (_, [_ = const {}]) {},
      ),
    );
    expect(find.byKey(const ValueKey('round-wrap')), findsOneWidget);
    expect(find.byKey(const ValueKey('round-wrap-again')), findsOneWidget);
    expect(find.byKey(const ValueKey('round-wrap-done')), findsNothing);
  });

  testWidgets('a board is touchable in a hand and inert on a wall', (
    tester,
  ) async {
    var picks = 0;
    await pump(
      tester,
      GameView(
        def: four,
        wire: boardWire(),
        audience: GameAudience.host,
        send: (i, [args = const {}]) {
          if (i == GameIntent.pick) picks++;
        },
      ),
    );
    final cells = find
        .descendant(
          of: find.byType(ShapeStageView),
          matching: find.byType(GestureDetector),
        )
        .evaluate()
        .toList();
    expect(cells, isNotEmpty);
    await tester.tap(find.byWidget(cells.first.widget));
    await tester.pump();
    expect(picks, 1, reason: 'the board you look at is the board you touch');

    await pump(
      tester,
      GameView(def: four, wire: boardWire(), audience: GameAudience.room),
    );
    final wall = find
        .descendant(
          of: find.byType(ShapeStageView),
          matching: find.byType(GestureDetector),
        )
        .evaluate()
        .toList();
    expect(wall, isNotEmpty);
    await tester.tap(find.byWidget(wall.first.widget));
    await tester.pump();
    expect(picks, 1, reason: 'a tap on a television means nothing');
  });
}
