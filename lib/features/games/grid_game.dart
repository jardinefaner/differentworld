import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/live_session/shape_stage_view.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter/material.dart';

/// One square on a board.
class BoardCell {
  const BoardCell({this.face, this.label, this.state = CellState.hidden});

  factory BoardCell.fromWire(Map<String, dynamic> m) => BoardCell(
    face: m['f'] as String?,
    label: m['l'] as String?,
    state: CellState.values[(m['s'] as num?)?.toInt() ?? 0],
  );

  final String? face;
  final String? label;
  final CellState state;

  BoardCell copyWith({String? face, String? label, CellState? state}) =>
      BoardCell(
        face: face ?? this.face,
        label: label ?? this.label,
        state: state ?? this.state,
      );

  Map<String, dynamic> toWire() => {
    's': state.index,
    if (face != null) 'f': face,
    if (label != null) 'l': label,
  };
}

/// A board mid-play.
class GridBoard {
  const GridBoard({
    required this.cols,
    required this.rows,
    required this.cells,
    this.turn = 0,
    this.done = false,
  });

  factory GridBoard.fromWire(Map<String, dynamic> m) => GridBoard(
    cols: (m['c'] as num?)?.toInt() ?? 4,
    rows: (m['r'] as num?)?.toInt() ?? 4,
    turn: (m['t'] as num?)?.toInt() ?? 0,
    done: m['d'] == true,
    cells: [
      for (final c in (m['cells'] as List? ?? const <dynamic>[]))
        if (c is Map) BoardCell.fromWire(c.cast<String, dynamic>()),
    ],
  );

  final int cols;
  final int rows;
  final List<BoardCell> cells;

  /// Whose go it is, for the two-sided games. Ignored by the rest.
  final int turn;
  final bool done;

  Map<String, dynamic> toWire() => {
    'c': cols,
    'r': rows,
    't': turn,
    'd': done,
    'cells': [for (final c in cells) c.toWire()],
  };

  GridBoard copyWith({List<BoardCell>? cells, int? turn, bool? done}) =>
      GridBoard(
        cols: cols,
        rows: rows,
        cells: cells ?? this.cells,
        turn: turn ?? this.turn,
        done: done ?? this.done,
      );

  int count(CellState s) => cells.where((c) => c.state == s).length;

  /// The cells with [i] swapped. Every rule in every classic is some version
  /// of "this one square changed", so it belongs here rather than re-spelled
  /// as an index-mapping comprehension in each game.
  List<BoardCell> withAt(int i, BoardCell cell) => [
    ...cells.sublist(0, i),
    cell,
    ...cells.sublist(i + 1),
  ];

  /// The cells with a state applied to every index in [at].
  List<BoardCell> withStateAt(Iterable<int> at, CellState state) {
    final set = at.toSet();
    return [
      for (var i = 0; i < cells.length; i++)
        if (set.contains(i)) cells[i].copyWith(state: state) else cells[i],
    ];
  }
}

/// A game that IS a board — the classics.
///
/// The point of the shape work made concrete. A grid game brings its board and
/// its rule for a tap; it does NOT bring a renderer, a wire format, a reducer
/// or a control bar. `buildStage` here delegates to the same
/// [ShapeStageView] the cast receiver uses, so a game written against this
/// base looks identical on the phone and on the TV by construction, and casts
/// to a screen that has never heard of it.
///
/// Before this, a board game cost ~500 lines (Reveal the Picture is 607,
/// Memory 561) because each one wrote its own stage AND its own remote. A
/// classic on this base is the board and the rule — usually under sixty.
abstract class GridGame extends GameDefinition<GridBoard> {
  const GridGame();

  int get cols;
  int get rows;

  /// Deal a fresh board.
  List<BoardCell> deal(ContentSource content);

  /// What a tap on [i] does. Return the new cells, or null to ignore the tap
  /// (an already-resolved square, a cell that is not this game's business).
  List<BoardCell>? onPick(GridBoard board, int i);

  /// Whether a tap hands play to the other side. False for the solitaire-ish
  /// ones (Bingo, Guess Who) where the room acts as one.
  bool get alternates => false;

  /// The line above the board, when the board needs one. Most do not.
  String? titleFor(GridBoard b) => null;

  /// The quieter second line — a score, a count, a whose-go.
  String? noteFor(GridBoard b) => null;

  /// A picture underneath the whole board (Reveal-the-Picture style). Null for
  /// every classic here; kept because the shape offers it.
  String? behindFor(GridBoard b) => null;

  @override
  bool get seedsFromContentBank => false;

  @override
  GridBoard decode(Map<String, dynamic> state) => GridBoard.fromWire(state);

  @override
  Map<String, dynamic> initialState(ContentSource content) => GridBoard(
    cols: cols,
    rows: rows,
    cells: deal(content),
  ).toWire();

  @override
  Set<GameIntent> activeIntents(GridBoard state) => {
    GameIntent.pick,
    GameIntent.reset,
  };

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final b = decode(state);
    switch (intent) {
      case GameIntent.pick:
        final i = (args['cell'] as num?)?.toInt();
        if (i == null || i < 0 || i >= b.cells.length) return state;
        final next = onPick(b, i);
        // A null means the rule declined the tap — an already-sunk ship, a
        // column with no room left. Returning the state unchanged is what
        // keeps a double-tap from costing a turn.
        if (next == null) return state;
        return b
            .copyWith(
              cells: next,
              turn: alternates ? (b.turn + 1) % 2 : b.turn,
            )
            .toWire();
      case GameIntent.reset:
        // Deal again. The content bank is not reachable from a pure reducer,
        // so a reset re-uses the faces already on the board, reshuffled by
        // the game if it cares (most classics keep the same set).
        return b
            .copyWith(
              cells: [
                for (final c in b.cells) c.copyWith(state: CellState.hidden),
              ],
              turn: 0,
              done: false,
            )
            .toWire();
      // Every other intent is a no-op for a board: there is no "next slide"
      // and no answer to reveal. Returning state unchanged means the standard
      // control bar can still send them harmlessly.
      // ignore: no_default_cases
      default:
        return state;
    }
  }

  @override
  StageShape? asShape(GridBoard state) => StageShape(
    kind: ShapeKind.grid,
    cols: state.cols,
    rows: state.rows,
    title: titleFor(state),
    note: noteFor(state),
    behind: behindFor(state),
    cells: [
      for (final c in state.cells)
        ShapeCell(state: c.state, face: c.face, label: c.label),
    ],
  );

  /// The phone draws exactly what the TV draws. No second implementation to
  /// drift, which is the bug class that produced the duplicate mini-boards.
  @override
  Widget buildStage(BuildContext context, GridBoard state) {
    // A board with no squares is a deck that has not loaded, not a game with
    // nothing in it. Rendering the empty grid would put a blank stage on the
    // room's TV with no explanation — the same shared empty state the other
    // deck-fed games use says what is actually wrong.
    if (state.cells.isEmpty) return const DeckEmptyStage();
    final shape = asShape(state);
    return shape == null
        ? const SizedBox.shrink()
        : ShapeStageView(shape: shape);
  }

  @override
  Widget? buildLiveStage(
    BuildContext context,
    GridBoard state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) {
    if (state.cells.isEmpty) return const DeckEmptyStage();
    final shape = asShape(state);
    if (shape == null) return null;
    return ShapeStageView(
      shape: shape,
      onPick: (i) => send(GameIntent.pick, {'cell': i}),
    );
  }
}
