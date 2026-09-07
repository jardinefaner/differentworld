import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_scaffold.dart';
import 'package:differentworld/features/live_session/shape_stage_view.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter/material.dart';

/// One square on a board.
class BoardCell {
  const BoardCell({
    this.face,
    this.label,
    this.state = CellState.hidden,
    this.tint = CellTint.none,
  });

  factory BoardCell.fromWire(Map<String, dynamic> m) => BoardCell(
    face: m['f'] as String?,
    label: m['l'] as String?,
    state: CellState.values[(m['s'] as num?)?.toInt() ?? 0],
    tint:
        CellTint.values[((m['c'] as num?)?.toInt() ?? 0).clamp(
          0,
          CellTint.values.length - 1,
        )],
  );

  final String? face;
  final String? label;
  final CellState state;
  final CellTint tint;

  /// **[copyWith] cannot CLEAR a field.** `copyWith(face: null)` keeps the
  /// existing face, because null is how the parameter says "unchanged". Snakes
  /// & Ladders hit this and grew a second token every move: the square the
  /// token left kept it. To empty a field, build a [BoardCell] instead.
  BoardCell copyWith({
    String? face,
    String? label,
    CellState? state,
    CellTint? tint,
  }) => BoardCell(
    face: face ?? this.face,
    label: label ?? this.label,
    state: state ?? this.state,
    tint: tint ?? this.tint,
  );

  Map<String, dynamic> toWire() => {
    's': state.index,
    if (face != null) 'f': face,
    if (label != null) 'l': label,
    if (tint != CellTint.none) 'c': tint.index,
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
    this.outcome,
    this.tally = const <String, int>{},
  });

  factory GridBoard.fromWire(Map<String, dynamic> m) => GridBoard(
    cols: (m['c'] as num?)?.toInt() ?? 4,
    rows: (m['r'] as num?)?.toInt() ?? 4,
    turn: (m['t'] as num?)?.toInt() ?? 0,
    done: m['d'] == true,
    outcome: m['o'] as String?,
    tally: {
      for (final e in (m['k'] as Map? ?? const <String, dynamic>{}).entries)
        '${e.key}': (e.value as num?)?.toInt() ?? 0,
    },
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

  /// The line to show when the round is over — "Bingo! Top row." — or null
  /// while it is still being played. Set by the reducer from
  /// [GridGame.outcomeFor]; a game never writes it directly.
  final String? outcome;

  /// Counters a rule needs that the cells can't hold — misses, wrong letters,
  /// guesses used, whose score is what. Small ints only; it rides the wire, so
  /// a board stays JSON-trivial and casts to a screen unchanged.
  ///
  /// Without this the classics had nowhere to count, which is part of why
  /// none of them could end: "three misses and you're out" needs a place to
  /// keep the three.
  final Map<String, int> tally;

  Map<String, dynamic> toWire() => {
    'c': cols,
    'r': rows,
    't': turn,
    'd': done,
    if (outcome != null) 'o': outcome,
    if (tally.isNotEmpty) 'k': tally,
    'cells': [for (final c in cells) c.toWire()],
  };

  GridBoard copyWith({
    List<BoardCell>? cells,
    int? turn,
    bool? done,
    String? outcome,
    Map<String, int>? tally,
  }) => GridBoard(
    cols: cols,
    rows: rows,
    cells: cells ?? this.cells,
    turn: turn ?? this.turn,
    done: done ?? this.done,
    outcome: outcome ?? this.outcome,
    tally: tally ?? this.tally,
  );

  /// Read a counter, defaulting to zero.
  int score(String key) => tally[key] ?? 0;

  /// The tally with [key] bumped by [by] — the shape every counting rule
  /// wants, so none of them re-spell the map copy.
  Map<String, int> plus(String key, [int by = 1]) => {
    ...tally,
    key: score(key) + by,
  };

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

  /// Whether a tap hands play to the other side. False for the ones where the
  /// room acts as one.
  ///
  /// **This is what makes a board into something a ROOM plays.** A game with
  /// no sides is a board being tapped: there is nothing to deliberate and no
  /// reason for anyone to talk, so it is something people look at rather than
  /// play. A game with sides gives the room two teams, a turn to argue over,
  /// and one pair of hands entering what they decided — which is how this app
  /// is meant to work everywhere else.
  bool get alternates => false;

  /// The two sides. Override for game-specific tokens (Connect Four's discs);
  /// the default reads as teams rather than colours.
  List<String> get sides => const ['Team 1', 'Team 2'];

  /// Whose go it is. Shown automatically under the board for any game that
  /// [alternates] and hasn't overridden [noteFor] — so turning a game into a
  /// team game costs one line.
  String? turnLine(GridBoard b) {
    if (!alternates || b.done || sides.isEmpty) return null;
    return '${sides[b.turn % sides.length]} to play';
  }

  /// Per-side score, kept in the tally under `p0` / `p1`.
  int scoreOf(GridBoard b, int side) => b.score('p$side');

  /// The tally with the CURRENT side's score bumped — the shape every
  /// two-sided rule wants.
  Map<String, int> plusForTurn(GridBoard b, [int by = 1]) =>
      b.plus('p${b.turn % sides.length}', by);

  /// "Team 1 4 · Team 2 2", or null before anyone has scored.
  String? scoreLine(GridBoard b) {
    if (!alternates) return null;
    final parts = <String>[];
    var any = false;
    for (var i = 0; i < sides.length; i++) {
      final n = scoreOf(b, i);
      if (n > 0) any = true;
      parts.add('${sides[i]} $n');
    }
    return any ? parts.join('  ·  ') : null;
  }

  /// **Is the round over, and what do we say about it?** Return null while
  /// the game is still being played; return the closing line when it is not.
  ///
  /// This is the half of a game loop the shape was missing. `GridBoard` has
  /// carried a `done` flag since the first classic shipped, `GameScaffold`
  /// has always drawn the "Round complete!" beat from it — and NOTHING ever
  /// set it, so nineteen classics dealt a board, accepted taps forever and
  /// could not be won, lost or finished. A game without an ending is a
  /// demonstration.
  ///
  /// Called after every pick, entry and tick. The reducer stamps `done` and
  /// the line onto the board, which lights the existing end-of-round beat
  /// (Play again · Done) with no per-game UI.
  String? outcomeFor(GridBoard b) => null;

  /// **Does this game have a clock?** Most don't — a classic waits for a tap.
  /// The few that are about being quick rather than being right (the mole
  /// that moves on its own, a sequence that plays itself back) do.
  bool get ticks => false;

  /// How often [onTick] fires while [ticks] is true and the round is live.
  Duration get tickEvery => const Duration(seconds: 1);

  /// What one beat of the clock does to the board. Return null to let the
  /// tick pass without changing anything.
  List<BoardCell>? onTick(GridBoard b) => null;

  /// Counters after a tap on [i] — pure: read [before], return the new tally.
  /// Default: unchanged.
  ///
  /// Separate from [onPick] because a rule's cells and a rule's counters are
  /// genuinely different questions, and folding them together would mean
  /// changing the signature every game is written against.
  Map<String, int> tallyAfterPick(GridBoard before, int i) => before.tally;

  /// Counters after one beat of the clock. Default: unchanged.
  Map<String, int> tallyAfterTick(GridBoard before) => before.tally;

  /// Counters a freshly-dealt board starts with. Default: none. Simon uses it
  /// to open in "the board is talking" rather than waiting for a tap that
  /// nobody can make yet.
  Map<String, int> get initialTally => const <String, int>{};

  /// The line above the board, when the board needs one. Most do not.
  String? titleFor(GridBoard b) => null;

  /// The quieter second line — a score, a count, a whose-go.
  String? noteFor(GridBoard b) => null;

  /// A word or phrase the host types in — Wordle's guess, a Scattergories
  /// answer, a crossword entry.
  ///
  /// Null (the default) means this game is played entirely by tapping, which
  /// is most of them. A game that returns a hint gets a field under its board
  /// on the PHONE only: the TV keeps drawing the shape, because a keyboard is
  /// a thing you hold, not a thing a room reads. That is the line between the
  /// shape and the instrument — the shape says what the room sees, and typing
  /// never belongs to the room.
  String? get entryHint => null;

  /// How many characters the entry takes, when it is fixed. Null = free text.
  int? get entryLength => null;

  /// Apply typed text. Return null to ignore it (a word of the wrong length,
  /// an entry after the round is over).
  List<BoardCell>? onEntry(GridBoard b, String text) => null;

  /// The cell as the ROOM should see it, which is not always the cell as the
  /// board stores it.
  ///
  /// Minesweeper keeps each square's neighbour count in its label from the
  /// moment it deals, because the count is the board — but showing it before
  /// the square is uncovered hands the room the whole answer. Default is
  /// identity; a game that hides part of itself overrides.
  BoardCell present(BoardCell c) => c;

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
    tally: initialTally,
  ).toWire();

  @override
  Set<GameIntent> activeIntents(GridBoard state) => {
    if (!state.done) GameIntent.pick,
    GameIntent.reset,
    if (entryHint != null && !state.done) GameIntent.capture,
  };

  /// Ask the game whether that move ended the round, and stamp the answer.
  /// Every state-changing branch of [reduce] goes through here so no game can
  /// accidentally be the one that never ends.
  Map<String, dynamic> _settle(GridBoard b) {
    final line = outcomeFor(b);
    if (line == null) return b.toWire();
    return b.copyWith(done: true, outcome: line).toWire();
  }

  @override
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  ) {
    final b = decode(state);
    switch (intent) {
      case GameIntent.pick:
        // A finished round takes no more taps. Without this a won board keeps
        // accepting picks behind the "Round complete!" beat.
        if (b.done) return state;
        final i = (args['cell'] as num?)?.toInt();
        if (i == null || i < 0 || i >= b.cells.length) return state;
        final next = onPick(b, i);
        // A null means the rule declined the tap — an already-sunk ship, a
        // column with no room left. Returning the state unchanged is what
        // keeps a double-tap from costing a turn.
        if (next == null) return state;
        return _settle(
          b.copyWith(
            cells: next,
            turn: alternates ? (b.turn + 1) % 2 : b.turn,
            tally: tallyAfterPick(b, i),
          ),
        );
      case GameIntent.tick:
        if (b.done || !ticks) return state;
        final next = onTick(b);
        if (next == null) return state;
        return _settle(b.copyWith(cells: next, tally: tallyAfterTick(b)));
      case GameIntent.capture:
        if (b.done) return state;
        final text = (args['text'] as String? ?? '').trim();
        if (text.isEmpty) return state;
        final next = onEntry(b, text);
        if (next == null) return state;
        return _settle(b.copyWith(cells: next));
      case GameIntent.reset:
        // Deal again. The content bank is not reachable from a pure reducer,
        // so a reset re-uses the faces already on the board, reshuffled by
        // the game if it cares (most classics keep the same set).
        //
        // Built explicitly rather than with copyWith, for the reason this
        // file already warns about on `BoardCell.face`: copyWith CANNOT clear
        // a field. `copyWith(done: false)` left the previous round's outcome
        // line and its tally in place, so "Play again" started you on three
        // misses and ended the new round on the first tick.
        return GridBoard(
          cols: b.cols,
          rows: b.rows,
          cells: [
            for (final c in b.cells) c.copyWith(state: CellState.hidden),
          ],
          tally: initialTally,
        ).toWire();
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
    // Once the round is over the closing line IS the title — the room
    // should read "Bingo! Top row." on the screen, not keep staring at a
    // board whose state no longer changes.
    title: state.done ? (state.outcome ?? titleFor(state)) : titleFor(state),
    // Whose go it is, when the game itself has nothing louder to say. This is
    // the line that lets a room take turns instead of watching one person tap.
    note: state.done ? null : (noteFor(state) ?? turnLine(state)),
    behind: behindFor(state),
    cells: [
      for (final raw in state.cells)
        if (present(raw) case final c)
          ShapeCell(
            state: c.state,
            face: c.face,
            label: c.label,
            tint: c.tint,
          ),
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
    final board = ShapeStageView(
      shape: shape,
      onPick: (i) => send(GameIntent.pick, {'cell': i}),
    );
    final hint = entryHint;
    if (hint == null) return board;
    return Column(
      children: [
        Expanded(child: board),
        _GridEntry(
          hint: hint,
          maxLength: entryLength,
          onSubmit: (t) {
            send(GameIntent.capture, {'text': t});
          },
        ),
      ],
    );
  }
}

/// The one field a typing game gets, under its board.
///
/// On the PHONE only — the receiver renders the shape and nothing else, so a
/// keyboard never appears on the room's screen. Clears itself on submit,
/// because the next guess is a new one and re-reading the last is not what
/// anybody wants.
class _GridEntry extends StatefulWidget {
  const _GridEntry({
    required this.hint,
    required this.onSubmit,
    this.maxLength,
  });

  final String hint;
  final int? maxLength;
  final void Function(String) onSubmit;

  @override
  State<_GridEntry> createState() => _GridEntryState();
}

class _GridEntryState extends State<_GridEntry> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _go() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    widget.onSubmit(t);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) => GameVerbBar(
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.go,
            maxLength: widget.maxLength,
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(
              hintText: widget.hint,
              counterText: '',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(onPressed: _go, child: const Text('Enter')),
      ],
    ),
  );
}
