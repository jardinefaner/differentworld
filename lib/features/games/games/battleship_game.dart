import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/room_beat.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';

/// **Battleship.** Ships hidden on a lettered grid; the room calls a square
/// and finds out.
///
/// The A1–D4 labels already existed for Reveal the Picture, for exactly this
/// reason — a room calling out a coordinate. This game is the closest thing
/// to free in the deck: the same grid, the same labels, the same three states.
class BattleshipGame extends GridGame {
  const BattleshipGame();

  static const _hit = '💥';
  static const _miss = '🌊';

  /// How many squares are ships. Five on a 5×5 keeps a round to a couple of
  /// minutes, which is the length of a brain break — and a younger room wants
  /// three while a room that has played it before wants eight.
  ///
  /// Eight also makes the DRAW real. With five ships and strict alternation
  /// the totals are 3-2 or 2-3 and never level, so `outcomeFor` declared a
  /// closing line ("a draw at N each") it could never say — measured at 0
  /// draws in 200 full boards. An even fleet is the only way a room ties.
  static const _ships = (3, 5, 8);

  @override
  List<GameSetting> get settings => [difficulty()];

  @override
  List<BoardCell> dealWith(
    ContentSource content,
    Map<String, Object?> values,
  ) => _lay(difficultyFrom(values).pick(_ships));

  /// The count rides the BOARD, because every line that reads it — the
  /// ending, the bar, the shot tally — is a pure function of the board and
  /// has no settings in hand.
  @override
  Map<String, int> tallyFrom(Map<String, Object?> values) => {
    'ships': difficultyFrom(values).pick(_ships),
  };

  /// A board dealt before the knob existed carries no 'ships'.
  static int _fleet(GridBoard b) =>
      b.tally['ships'] is int && b.tally['ships']! > 0
      ? b.tally['ships']!
      : GameDifficulty.usual.pick(_ships);

  @override
  String get id => 'battleship';

  @override
  String get title => 'Battleship';

  @override
  RunScript get howToPlay => const [
    RoomBeat('We are playing Battleship'),
    RoomBeat('Ships are hiding under the squares'),
    RoomBeat(
      'Call out a square, like B3',
      detail: 'Splash is a miss, boom is a hit',
    ),
    RoomBeat('Find them all to finish'),
    RoomBeat('Team 1 calls first'),
  ];

  @override
  GameVibe get vibe => const GameVibe(accent: GameAccents.slate);

  /// Two teams call squares in turn. Solitaire, this was one person tapping
  /// twenty-five boxes; with sides it is a room arguing about where the ships
  /// are and one pair of hands entering the call.
  @override
  bool get alternates => true;

  @override
  int get cols => 5;

  @override
  int get rows => 5;

  /// The label a room says out loud. Column letter, row number — B3.
  static String label(int i, int cols) =>
      '${String.fromCharCode(65 + i % cols)}${i ~/ cols + 1}';

  @override
  List<BoardCell> deal(ContentSource content) =>
      _lay(GameDifficulty.usual.pick(_ships));

  List<BoardCell> _lay(int count) {
    final r = Random();
    final ships = <int>{};
    while (ships.length < count) {
      ships.add(r.nextInt(cols * rows));
    }
    return [
      for (var i = 0; i < cols * rows; i++)
        BoardCell(
          label: label(i, cols),
          // The ship rides in the FACE. It is NOT automatically unseen while
          // the cell is hidden — the renderer draws a face whenever there is
          // one, whatever the state — so [present] does the hiding. Without
          // that override every ship was visible from the first frame AND the
          // coordinate labels never rendered, because a cell with a face
          // never shows its label. The whole game was on the screen.
          face: ships.contains(i) ? _hit : _miss,
        ),
    ];
  }

  /// A square not yet fired on shows its COORDINATE, not its contents. This
  /// is the whole game: the room calls "B3" and finds out.
  @override
  BoardCell present(BoardCell c) =>
      c.state == CellState.hidden ? BoardCell(label: c.label, tint: c.tint) : c;

  @override
  List<BoardCell>? onPick(GridBoard b, int i) {
    // Already fired on. Declining the tap is what stops a double-tap from
    // reading as two shots.
    if (b.cells[i].state != CellState.hidden) return null;
    return b.withAt(i, b.cells[i].copyWith(state: CellState.shown));
  }

  /// A hit scores for whoever called it.
  @override
  Map<String, int> tallyAfterPick(GridBoard before, int i) =>
      (before.cells[i].state == CellState.hidden &&
          before.cells[i].face == _hit)
      ? plusForTurn(before)
      : before.tally;

  /// Every ship found — and now it matters WHO found them.
  @override
  String? outcomeFor(GridBoard b) {
    if (_sunk(b) != _fleet(b)) return null;
    final a = scoreOf(b, 0);
    final c = scoreOf(b, 1);
    if (a == c) return 'All hit — a draw at $a each';
    return '${sides[a > c ? 0 : 1]} wins, $a–$c';
  }

  /// Ships found so far, as a bar that fills.
  @override
  double? progressFor(GridBoard b) =>
      _sunk(b) == 0 ? null : (_sunk(b) / _fleet(b)).clamp(0.0, 1.0);

  @override
  String? titleFor(GridBoard b) => _sunk(b) == _fleet(b) ? 'All hit!' : null;

  @override
  String? noteFor(GridBoard b) {
    final score = scoreLine(b);
    final turn = turnLine(b);
    if (score != null && turn != null) return '$turn\n$score';
    return _legacyNote(b) ?? turn;
  }

  String? _legacyNote(GridBoard b) {
    final hit = _sunk(b);
    final shots = b.cells.where((c) => c.state != CellState.hidden).length;
    if (shots == 0) return null;
    return '$hit of ${_fleet(b)} · $shots ${shots == 1 ? 'shot' : 'shots'}';
  }

  int _sunk(GridBoard b) => b.cells
      .where((c) => c.state != CellState.hidden && c.face == _hit)
      .length;
}
