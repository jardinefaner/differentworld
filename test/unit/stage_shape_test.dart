// The claim shapes are supposed to buy: a receiver can draw a game it has
// never heard of.
//
// The cast wire names a GAME, and the receiver resolves that id in its own
// registry. That works right up until the two devices are on different
// builds — then a wall-mounted screen nobody updates can only say "this
// session needs a newer version", and the activity simply cannot reach the
// room. Shapes ride alongside: the phone also DESCRIBES the stage, so a
// receiver that understands the shape draws it without knowing the game.
//
// These tests are about that property, not about pixels.

import 'package:differentworld/features/games/games/grid_reveal_game.dart';
import 'package:differentworld/features/games/games/memory_match_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reveal = GridRevealGame();
  const memory = MemoryMatchGame();

  StageShape revealShape({List<bool>? rev}) => reveal.asShape(
    reveal.decode({
      'pic': '🦁',
      'lbl': 'lion',
      'cols': 4,
      'rows': 4,
      'rev': rev ?? List<bool>.filled(16, false),
    }),
  )!;

  test('two different games come out the same shape', () {
    final m = memory.asShape(
      memory.decode({
        'cards': [
          for (var i = 0; i < 4; i++)
            {'image': '🍎', 'label': 'apple', 'pair': 'p$i'},
        ],
        'flipped': <int>[],
        'matched': <int>[],
      }),
    );
    expect(revealShape().kind, ShapeKind.grid);
    expect(m?.kind, ShapeKind.grid);
    // The point is not that they are identical — it is that ONE renderer on
    // the TV serves both, which is only true if they speak one vocabulary.
  });

  test('a shape survives the wire', () {
    final before = revealShape(rev: [true, ...List<bool>.filled(15, false)]);
    final after = StageShape.fromWire(before.toWire())!;
    expect(after.kind, before.kind);
    expect(after.cols, before.cols);
    expect(after.rows, before.rows);
    expect(after.behind, before.behind);
    expect(after.cells.length, before.cells.length);
    expect(after.cells.first.state, CellState.shown);
    expect(after.cells[1].state, CellState.hidden);
    expect(after.cells.first.label, 'A1');
  });

  test('the shape tracks state, it is not a one-time snapshot', () {
    // A stale shape would show the room the PREVIOUS move, which is worse
    // than showing nothing.
    final none = revealShape();
    final one = revealShape(rev: [true, ...List<bool>.filled(15, false)]);
    expect(none.cells.first.state, CellState.hidden);
    expect(one.cells.first.state, CellState.shown);
  });

  test('an undescribed stage yields no shape, and that is fine', () {
    // Most games have not been migrated and must not be forced to. Null here
    // is what keeps them on the named-game path untouched.
    expect(StageShape.fromWire(null), isNull);
    expect(StageShape.fromWire(const {}), isNull);
  });

  test('junk on the wire degrades to null, never throws', () {
    // The wire crosses devices and versions; a malformed shape must not take
    // the TV down mid-session.
    expect(StageShape.fromWire(const {'k': 999, 'cells': <dynamic>[]}), isNull);
    expect(StageShape.fromWire(const {'k': 0, 'cells': 'not a list'}), isNull);
    expect(StageShape.fromWire(const {'k': -1, 'cells': <dynamic>[]}), isNull);
  });

  test('a memory cell carries its face; a reveal cell carries its label', () {
    // The two games use the same grid differently — faces per cell versus one
    // picture behind the board. If the vocabulary could not hold both, it
    // would not be a shared shape, just Reveal the Picture with extra steps.
    final r = revealShape();
    expect(r.behind, '🦁');
    expect(r.cells.first.face, isNull);
    expect(r.cells.first.label, isNotNull);

    final m = memory.asShape(
      memory.decode({
        'cards': [
          {'image': '🍎', 'label': 'apple', 'pair': 'a'},
          {'image': '🍎', 'label': 'apple', 'pair': 'a'},
        ],
        'flipped': <int>[],
        'matched': <int>[],
      }),
    )!;
    expect(m.behind, isNull);
    expect(m.cells.first.face, '🍎');
  });
}
