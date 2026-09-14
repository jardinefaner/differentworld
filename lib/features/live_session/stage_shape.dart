/// What the room's screen should DRAW, described rather than named.
///
/// The cast wire currently names a GAME: `{game: 'grid-reveal', state: {…}}`.
/// The receiver looks that id up in its own registry and draws it with code
/// compiled into that build. It works, and it costs ~220 lines per castable
/// activity — a stage and a remote, written twice — which is why 9 of 27 brain
/// breaks reach a TV and 18 can only be mirrored. It also means a TV on an
/// older build can only say "this session needs a newer version", because the
/// id is meaningless to it.
///
/// A SHAPE is the other half of that trade. The phone describes the stage in a
/// small vocabulary; the receiver has one renderer per shape, built once. A
/// game that describes itself casts to a screen that has never heard of it,
/// because the vocabulary changes far more slowly than the activity list.
///
/// This is deliberately NOT a general scene graph. The vocabulary is small and
/// closed on purpose: expressiveness is the thing you trade away to make an
/// old receiver able to draw a new game. A stage that cannot be said in
/// shapes keeps naming its game and keeps its bespoke renderer — the two
/// paths coexist, and [StageShape] is only ever an addition to the wire.
library;

/// The vocabulary. One entry per renderer the receiver ships.
enum ShapeKind {
  /// A rows x cols board of cells, each hidden / shown / finished, optionally
  /// over a picture. Covers Reveal the Picture, Memory, Name It, Odd One Out
  /// and What's Missing — five games, one renderer.
  grid,
}

/// How a single cell reads to the room.
enum CellState {
  /// Face down: the cover is drawn, whatever is underneath is not.
  hidden,

  /// Face up: this cell's own face, or the picture behind the board.
  shown,

  /// Resolved and out of play — a matched pair, an eliminated option. Drawn
  /// quieter than [shown] so the room can see what is left to do.
  done,
}

/// What a cell MEANS, when its state alone cannot say it.
///
/// Deliberately semantic rather than a colour: the wire says "this one was
/// right", and the receiver decides what right looks like in its theme. A hex
/// on the wire would hardcode one device's palette into every other device's
/// screen.
enum CellTint {
  /// No claim — the ordinary case.
  none,

  /// Correct, safe, found.
  right,

  /// Nearly — the right letter in the wrong place, a near miss.
  close,

  /// Wrong, or dangerous.
  wrong,

  /// Lit, active, switched on.
  live,
}

/// How a whole board is DRAWN — the second axis of the vocabulary, beside
/// [ShapeKind]. A grid of tiles and a grid of holes carry the same cells; the
/// style says what a cell looks like, so the classics stop being nineteen
/// boards of identical white squares with emoji on them.
///
/// Still closed, still small: one entry per look the receiver can draw. An
/// older receiver that meets a style it does not know reads it as [tiles],
/// which is what it drew before.
enum ShapeStyle {
  /// Rounded square tiles — the default, and right for most boards.
  tiles,

  /// Big rounded pads, one colour each — Simon, Four Corners. Meant to be
  /// looked at from across a room and lit one at a time.
  pads,

  /// A framed board of round holes; a face-up cell is a disc dropped into
  /// its hole — Connect Four.
  holes,

  /// A dots-and-edges lattice at double resolution: even/even cells are
  /// dots, odd/even are edges, odd/odd are boxes — Dots & Boxes.
  lattice,
}

/// One position on a [ShapeKind.grid].
class ShapeCell {
  const ShapeCell({
    required this.state,
    this.label,
    this.face,
    this.tint = CellTint.none,
    this.slot = 0,
  });

  factory ShapeCell.fromWire(Map<String, dynamic> m) => ShapeCell(
    state: CellState.values[(m['s'] as num?)?.toInt() ?? 0],
    label: m['l'] as String?,
    face: m['f'] as String?,
    tint:
        CellTint.values[((m['c'] as num?)?.toInt() ?? 0).clamp(
          0,
          CellTint.values.length - 1,
        )],
    slot: ((m['p'] as num?)?.toInt() ?? 0).clamp(0, 8),
  );

  final CellState state;

  /// Which of the board's palette slots this cell belongs to — 1..8, or 0
  /// for none. IDENTITY rather than judgement, which is what [tint] is for:
  /// "this is the red side's disc", "this is pad three". The receiver picks
  /// the colour for a slot in its own palette, so no hex crosses the wire.
  final int slot;

  /// What the cover says while hidden — "B3". Null when the cover is blank,
  /// which is right for Memory: nobody calls a card by coordinate.
  final String? label;

  /// What this cell shows when face up: an emoji, or an image path. Null when
  /// the board reveals a shared picture behind it instead.
  final String? face;

  /// What the cell means beyond its state — right, close, wrong, live.
  final CellTint tint;

  Map<String, dynamic> toWire() => {
    's': state.index,
    if (label != null) 'l': label,
    if (face != null) 'f': face,
    if (tint != CellTint.none) 'c': tint.index,
    if (slot != 0) 'p': slot,
  };
}

/// A described stage. Rides the cast wire next to the game id, so a receiver
/// that knows the shape can draw it and one that doesn't still falls back to
/// the named-game path.
class StageShape {
  const StageShape({
    required this.kind,
    required this.cols,
    required this.rows,
    required this.cells,
    this.title,
    this.note,
    this.behind,
    this.behindIsImage = false,
    this.style = ShapeStyle.tiles,
    this.progress,
  });

  final ShapeKind kind;
  final int cols;
  final int rows;
  final List<ShapeCell> cells;

  /// How the board is drawn — see [ShapeStyle].
  final ShapeStyle style;

  /// How far through something the room is, 0..1 — the sand left in Boggle,
  /// the lives left in Hangman. Drawn as a thin bar under the note. Null
  /// when the board has nothing to measure, which is most of them.
  final double? progress;

  /// The line above the board — "Find the matching pairs". Optional, because
  /// a board that explains itself does not need one.
  final String? title;

  /// A quieter second line — "0 / 6 pairs", or the answer once it is out.
  final String? note;

  /// A picture UNDER the whole board, uncovered cell by cell. Emoji by
  /// default; an image path when [behindIsImage].
  final String? behind;
  final bool behindIsImage;

  Map<String, dynamic> toWire() => {
    'k': kind.index,
    'c': cols,
    'r': rows,
    'cells': [for (final c in cells) c.toWire()],
    if (title != null) 't': title,
    if (note != null) 'n': note,
    if (behind != null) 'b': behind,
    if (behindIsImage) 'bi': true,
    if (style != ShapeStyle.tiles) 'st': style.index,
    if (progress != null) 'pr': progress,
  };

  /// Null when the wire carries no shape — an older phone, or a game that has
  /// not been described. Callers fall back to the named-game renderer.
  static StageShape? fromWire(Map<String, dynamic>? m) {
    if (m == null) return null;
    final k = (m['k'] as num?)?.toInt();
    if (k == null || k < 0 || k >= ShapeKind.values.length) return null;
    final raw = m['cells'];
    if (raw is! List) return null;
    return StageShape(
      kind: ShapeKind.values[k],
      cols: (m['c'] as num?)?.toInt() ?? 1,
      rows: (m['r'] as num?)?.toInt() ?? 1,
      cells: [
        for (final c in raw)
          if (c is Map) ShapeCell.fromWire(c.cast<String, dynamic>()),
      ],
      title: m['t'] as String?,
      note: m['n'] as String?,
      behind: m['b'] as String?,
      behindIsImage: m['bi'] == true,
      // An unknown style (a newer phone) reads as tiles — the look every
      // receiver already had.
      style: switch ((m['st'] as num?)?.toInt() ?? 0) {
        final i when i >= 0 && i < ShapeStyle.values.length =>
          ShapeStyle.values[i],
        _ => ShapeStyle.tiles,
      },
      progress: (m['pr'] as num?)?.toDouble().clamp(0.0, 1.0),
    );
  }
}
