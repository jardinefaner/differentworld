// GameView is the one thing that draws a game, so what it decides is what
// every surface shows. These pin the four audiences against the four ways a
// surface can be wrong: no beats, no Next, a secret on the room's screen, and
// a board that cannot be touched where it is the instrument.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_view.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/connect_four_game.dart';
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
