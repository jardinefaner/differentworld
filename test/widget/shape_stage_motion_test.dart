// The shared board renderer's styles and motion — every classic renders
// through it, so a style that overflows or a beat that throws breaks nineteen
// games at once. Phone-sized, both the still and the moving case.

import 'package:differentworld/features/games/celebration.dart';
import 'package:differentworld/features/games/game_motion.dart';
import 'package:differentworld/features/live_session/shape_stage_view.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StageShape board(ShapeStyle style, {int cols = 4, int rows = 4}) =>
      StageShape(
        kind: ShapeKind.grid,
        cols: cols,
        rows: rows,
        style: style,
        title: 'A title',
        note: 'A note',
        progress: 0.5,
        cells: [
          for (var i = 0; i < cols * rows; i++)
            ShapeCell(
              state: i.isEven ? CellState.shown : CellState.hidden,
              label: 'L$i',
              slot: (i % 4) + 1,
              tint: i == 2 ? CellTint.live : CellTint.none,
            ),
        ],
      );

  Future<List<String>> pumpBoard(
    WidgetTester tester,
    StageShape shape, {
    bool motion = true,
  }) async {
    final errors = <String>[];
    final prior = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString());
    addTearDown(() => FlutterError.onError = prior);
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameMotion(
            enabled: motion,
            child: ShapeStageView(shape: shape, onPick: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();
    // Through the deal-in stagger and the beat.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    return errors;
  }

  for (final style in ShapeStyle.values) {
    testWidgets('the $style style lays out on a phone without overflow', (
      tester,
    ) async {
      final cols = style == ShapeStyle.lattice ? 7 : 4;
      final rows = style == ShapeStyle.lattice ? 7 : 4;
      final errors = await pumpBoard(
        tester,
        board(style, cols: cols, rows: rows),
      );
      expect(errors, isEmpty, reason: errors.join('\n'));
      expect(find.text('A title'), findsOneWidget);
      expect(find.text('A note'), findsOneWidget);
    });
  }

  testWidgets('a changed cell animates, then settles', (tester) async {
    await pumpBoard(tester, board(ShapeStyle.holes));
    // Flip cell 1 from hidden to shown — the drop beat.
    final next = board(ShapeStyle.holes);
    final cells = [...next.cells];
    cells[1] = const ShapeCell(state: CellState.shown, slot: 2);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameMotion(
            enabled: true,
            child: ShapeStageView(
              shape: StageShape(
                kind: ShapeKind.grid,
                cols: 4,
                rows: 4,
                style: ShapeStyle.holes,
                cells: cells,
              ),
              onPick: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('with motion off nothing runs and the board still draws', (
    tester,
  ) async {
    final errors = await pumpBoard(
      tester,
      board(ShapeStyle.tiles),
      motion: false,
    );
    expect(errors, isEmpty);
    expect(find.byType(ShapeStageView), findsOneWidget);
  });

  testWidgets('the celebration plays on the false → true edge only', (
    tester,
  ) async {
    Widget layer({required bool done}) => MaterialApp(
      home: Scaffold(
        body: GameMotion(
          enabled: true,
          haptics: false,
          child: CelebrationLayer(
            done: done,
            accent: Colors.teal,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    // Mounting already-done: no burst (a late-joining receiver).
    await tester.pumpWidget(layer(done: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('celebration-burst')), findsNothing);

    await tester.pumpWidget(layer(done: false));
    await tester.pump();
    await tester.pumpWidget(layer(done: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.byKey(const ValueKey('celebration-burst')),
      findsOneWidget,
      reason: 'the burst',
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('celebration-burst')),
      findsNothing,
      reason: 'and it is over',
    );
  });
}
