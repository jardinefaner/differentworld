import 'dart:async';
import 'dart:math';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_motion.dart';
import 'package:differentworld/features/games/game_sounds.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Draws a [StageShape]. ONE renderer per shape, shared by every game that
/// describes itself that way.
///
/// This is the half of the shape protocol that makes it worth doing. Reveal
/// the Picture and Memory both hand over a `grid`, and this widget draws both
/// without knowing either exists — so a receiver on an older build can show a
/// grid game shipped after it, instead of "this session needs a newer version".
///
/// **And it is where the classics come alive.** Nineteen board games render
/// through here, so motion added once is motion on every one of them, on the
/// phone AND the TV: a board deals itself in left to right, a turned cell
/// flips, a right answer pops, a wrong one shakes, a disc drops down its
/// column, a lit pad glows. The games still bring only a board and a rule —
/// a style word and a colour slot are the whole of what they add.
///
/// A raw canvas: this is the TV, hardcoded dark per docs/THEME_ADHERENCE.md.
class ShapeStageView extends StatelessWidget {
  const ShapeStageView({
    required this.shape,
    this.onPick,
    this.onLongPick,
    super.key,
  });

  final StageShape shape;

  /// Tap a cell. Null on the receiver (the room does not touch the TV) and
  /// set on the phone, where the board IS the instrument.
  final void Function(int index)? onPick;

  /// Hold a cell — the board's second verb, for the games that have one
  /// (Minesweeper's flag). Null everywhere else, and always on the receiver.
  final void Function(int index)? onLongPick;

  @override
  Widget build(BuildContext context) => switch (shape.kind) {
    ShapeKind.grid => _Grid(
      shape: shape,
      onPick: onPick,
      onLongPick: onLongPick,
    ),
  };
}

/// The palette a [ShapeCell.slot] resolves to — the receiver's choice, so no
/// hex crosses the wire. Slot 1 and 2 are the two sides of any two-team game
/// (a clay red and a clear gold, the two discs every Connect Four ever had);
/// 3..8 are the rest of the harmonized game accents, for pads and tokens.
const List<Color> _slotColors = <Color>[
  Colors.transparent, // slot 0: none
  GameAccents.coral, // 1 — red side
  ActivityPalette.yellow, // 2 — yellow side
  GameAccents.teal, // 3
  GameAccents.slate, // 4
  GameAccents.plum, // 5
  GameAccents.sage, // 6
  GameAccents.rose, // 7
  GameAccents.deepTeal, // 8
];

Color _slotColor(int slot) =>
    _slotColors[slot.clamp(0, _slotColors.length - 1)];

class _Grid extends StatelessWidget {
  const _Grid({required this.shape, this.onPick, this.onLongPick});

  final StageShape shape;
  final void Function(int index)? onPick;
  final void Function(int index)? onLongPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final lattice = shape.style == ShapeStyle.lattice;
    final holes = shape.style == ShapeStyle.holes;
    // A lattice is a grid at double resolution — the dots and edges are thin,
    // the boxes wide — so its aspect ratio counts the boxes, not the cells.
    final aspect = lattice
        ? _latticeSpan(shape.cols) / _latticeSpan(shape.rows)
        : shape.cols / shape.rows;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (shape.title case final t?)
            Text(
              t,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white70, // raw-canvas: TV stage
              ),
            ),
          if (shape.note case final n?) ...[
            const SizedBox(height: 4),
            Text(
              n,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white, // raw-canvas: TV stage
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (shape.progress case final p?) ...[
            const SizedBox(height: 12),
            _ProgressBar(fraction: p, accent: accent),
          ],
          if (shape.title != null ||
              shape.note != null ||
              shape.progress != null)
            const SizedBox(height: 16),
          Flexible(
            child: AspectRatio(
              aspectRatio: aspect,
              child: Container(
                // The holes style is a FRAMED board — a blue rack the discs
                // sit in, which is what makes it read as Connect Four from
                // across a room rather than a grid of grey circles.
                padding: holes ? const EdgeInsets.all(8) : EdgeInsets.zero,
                decoration: holes
                    ? BoxDecoration(
                        color: const Color(0xFF3D5A78), // raw-canvas: TV stage
                        borderRadius: BorderRadius.circular(18),
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(holes ? 12 : 16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (shape.behind case final b?)
                        _Behind(b, isImage: shape.behindIsImage),
                      Column(
                        children: [
                          for (var r = 0; r < shape.rows; r++)
                            Expanded(
                              flex: lattice ? _latticeFlex(r) : 1,
                              child: Row(
                                children: [
                                  for (var c = 0; c < shape.cols; c++)
                                    Expanded(
                                      flex: lattice ? _latticeFlex(c) : 1,
                                      child: _cellAt(
                                        context,
                                        r * shape.cols + c,
                                        r,
                                        c,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Dots (even) are a sliver; edges and boxes (odd) take the room.
  static int _latticeFlex(int i) => i.isEven ? 1 : 4;

  static int _latticeSpan(int n) {
    var span = 0;
    for (var i = 0; i < n; i++) {
      span += _latticeFlex(i);
    }
    return span;
  }

  Widget _cellAt(BuildContext context, int i, int row, int col) {
    if (i >= shape.cells.length) return const SizedBox.shrink();
    final cell = shape.cells[i];
    // A shown cell over a shared picture must be a HOLE, not a tile — the
    // point is to see through to the picture underneath.
    final seeThrough = cell.state != CellState.hidden && shape.behind != null;
    final gap = switch (shape.style) {
      ShapeStyle.tiles => shape.behind == null ? 4.0 : 0.0,
      ShapeStyle.pads => 6.0,
      ShapeStyle.holes => 3.0,
      ShapeStyle.lattice => 0.0,
    };
    return Padding(
      padding: EdgeInsets.all(gap),
      child: GestureDetector(
        // EVERY cell is a target; the game's own rule decides whether the tap
        // counts (`GridGame.onPick` returns null to decline, which is what
        // keeps a double-tap from costing a turn).
        //
        // This used to fire only for a face-DOWN cell — written for Reveal
        // the Picture, where a lifted tile must not re-send its pick — and it
        // silently killed every classic whose squares start face-UP: Bingo,
        // Boggle, Word Search, Guess Who, Four Corners, Scavenger, Simon,
        // Snakes & Ladders, Lights Out, Spot the Difference. Ten boards that
        // could be looked at and not played. The lifted-tile case is covered
        // by [seeThrough] below: an open cell over a picture is an empty box
        // that no tap can land on.
        onTap: onPick == null
            ? null
            : () {
                if (GameMotion.hapticsOf(context)) {
                  unawaited(HapticFeedback.selectionClick());
                }
                onPick?.call(i);
              },
        onLongPress: onLongPick == null ? null : () => onLongPick?.call(i),
        child: seeThrough
            ? const SizedBox.expand()
            : _AnimatedCell(
                key: ValueKey('cell-$i'),
                cell: cell,
                index: i,
                row: row,
                col: col,
                style: shape.style,
                framed: shape.behind != null,
              ),
      ),
    );
  }
}

/// The thin measure under the note — sand left, lives left.
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction, required this.accent});

  final double fraction;
  final Color accent;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          child: Stack(
            children: [
              const ColoredBox(
                color: Colors.white12, // raw-canvas: TV stage
                child: SizedBox.expand(),
              ),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0.0, 1.0),
                child: ColoredBox(color: accent),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Behind extends StatelessWidget {
  const _Behind(this.ref, {required this.isImage});

  final String ref;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    if (isImage) {
      return PersonPhotoNetwork(
        urlOrPath: ref,
        placeholderBuilder: (_) => const ColoredBox(color: Colors.white),
      );
    }
    // An emoji's line box is taller than its ink, so a plain FittedBox leaves
    // the picture floating in the middle of the board and only the centre
    // cells carry any of it. Kill the leading, then overscale past the edges
    // (clipped by the caller).
    return ColoredBox(
      color: Colors.white, // raw-canvas: TV stage
      child: Transform.scale(
        scale: 1.3,
        child: FittedBox(
          fit: BoxFit.cover,
          child: Text(
            ref,
            style: const TextStyle(fontSize: 240, height: 1),
          ),
        ),
      ),
    );
  }
}

/// What just happened to a cell, which decides how it moves.
enum _Beat { none, deal, flip, pop, shake, drop }

/// One cell, and the motion of its last change.
///
/// Stateful ONLY for the animation clock: the cell itself is still a pure
/// function of the wire, rebuilt on every intent. `didUpdateWidget` compares
/// the cell it had with the cell it has and picks a beat — so "what moved"
/// is answered by the board, which is the question a room asks after every
/// tap (CLAUDE.md, "motion instead of cuts").
class _AnimatedCell extends StatefulWidget {
  const _AnimatedCell({
    required this.cell,
    required this.index,
    required this.row,
    required this.col,
    required this.style,
    required this.framed,
    super.key,
  });

  final ShapeCell cell;
  final int index;
  final int row;
  final int col;
  final ShapeStyle style;
  final bool framed;

  @override
  State<_AnimatedCell> createState() => _AnimatedCellState();
}

class _AnimatedCellState extends State<_AnimatedCell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  _Beat _beat = _Beat.none;
  Timer? _dealIn;

  @override
  void initState() {
    super.initState();
    // The deal-in: cells settle left to right, top to bottom, a few
    // milliseconds apart, capped so a 64-square word search is not a slow
    // wipe. Deferred to after the first frame so GameMotion.of can be read.
    // On a REPLAY the cells survive (stable keys) and this does not run
    // again: a fresh deal shows itself through didUpdateWidget instead — a
    // cell going face-down deals in, a new face pops — so the second round
    // still moves without re-running the opening wipe.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !GameMotion.read(context)) return;
      final delay = Duration(milliseconds: min(widget.index * 18, 420));
      _dealIn = Timer(delay, () {
        if (mounted) _play(_Beat.deal);
      });
    });
  }

  @override
  void didUpdateWidget(_AnimatedCell old) {
    super.didUpdateWidget(old);
    final was = old.cell;
    final now = widget.cell;
    // A pad that lights up sounds its note — Simon's four, and the chosen
    // corner in Four Corners. Sound is not motion: it plays with reduced
    // motion on, and stops only with the Preferences switch.
    if (widget.style == ShapeStyle.pads &&
        now.tint == CellTint.live &&
        was.tint != CellTint.live &&
        GameMotion.soundOf(context)) {
      final note = GameSoundAsset.forSlot(now.slot);
      if (note != null) GameSounds.play(note);
    }
    if (!GameMotion.read(context)) return;
    _Beat? beat;
    if (was.state == CellState.hidden && now.state != CellState.hidden) {
      beat = widget.style == ShapeStyle.holes ? _Beat.drop : _Beat.flip;
    } else if (was.state != CellState.hidden && now.state == CellState.hidden) {
      // Face-down again: a fresh deal (Play again). Settle in, don't snap.
      beat = _Beat.deal;
    } else if (now.tint == CellTint.wrong && was.tint != CellTint.wrong) {
      beat = _Beat.shake;
    } else if ((now.tint == CellTint.right || now.tint == CellTint.live) &&
        now.tint != was.tint) {
      beat = _Beat.pop;
    } else if (now.face != was.face && now.face != null) {
      beat = _Beat.pop;
    } else if (now.slot != was.slot && now.slot != 0) {
      beat = widget.style == ShapeStyle.holes ? _Beat.drop : _Beat.pop;
    }
    if (beat != null) _play(beat);
  }

  void _play(_Beat beat) {
    _beat = beat;
    _clock
      ..stop()
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _dealIn?.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final face = _Cell(
      cell: widget.cell,
      style: widget.style,
      framed: widget.framed,
      row: widget.row,
      col: widget.col,
    );
    // The LayoutBuilder is not decoration: the drop beat falls from the top
    // of the column, which is `(row + 1) × this cell's height`, and the
    // height is only known here. A child's per-frame rebuild does not re-run
    // this builder (a Transform never changes the cell's size).
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: _clock,
        child: face,
        builder: (context, child) {
          if (!_clock.isAnimating || _beat == _Beat.none) return child!;
          final t = _clock.value;
          switch (_beat) {
            case _Beat.deal:
              final k = Curves.easeOutBack.transform(t);
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.scale(scale: 0.6 + 0.4 * k, child: child),
              );
            case _Beat.flip:
              // Grows out from its vertical centre line — the near half of
              // a flip, which is the half that reads as "turned over".
              final k = Curves.easeOutCubic.transform(t);
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.diagonal3Values(0.15 + 0.85 * k, 1, 1),
                child: child,
              );
            case _Beat.pop:
              return Transform.scale(
                scale: 1 + 0.16 * sin(pi * t),
                child: child,
              );
            case _Beat.shake:
              return Transform.translate(
                offset: Offset(sin(t * pi * 4) * 6 * (1 - t), 0),
                child: child,
              );
            case _Beat.drop:
              // Falls from the top of its column and lands with a bounce —
              // the one thing a Connect Four disc has always done.
              final fall = (widget.row + 1) * constraints.maxHeight;
              final k = Curves.bounceOut.transform(t);
              return Transform.translate(
                offset: Offset(0, -fall * (1 - k)),
                child: child,
              );
            case _Beat.none:
              return child!;
          }
        },
      ),
    );
  }
}

/// A cell, still — its look by style.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.cell,
    required this.style,
    required this.framed,
    required this.row,
    required this.col,
  });

  final ShapeCell cell;
  final ShapeStyle style;
  final bool framed;

  /// Where the cell sits — the lattice reads dots, edges and boxes off the
  /// parity of its position, so the game never has to say which is which.
  final int row;
  final int col;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = Theme.of(context).extension<AppColors>();
    final accent = scheme.primary;
    // The tint decides the FACE colour, not the state — a cell can be face-up
    // and still be telling the room it was wrong.
    final tinted = switch (cell.tint) {
      CellTint.none => null,
      CellTint.right => app?.growth ?? scheme.primary,
      CellTint.close => scheme.tertiary,
      CellTint.wrong => scheme.error,
      CellTint.live => accent,
    };
    return switch (style) {
      ShapeStyle.tiles => _tile(tinted, accent),
      ShapeStyle.pads => _pad(),
      ShapeStyle.holes => _hole(),
      ShapeStyle.lattice => _latticePiece(),
    };
  }

  bool get _down => cell.state == CellState.hidden;
  bool get _done => cell.state == CellState.done;

  /// The label or the face, whichever the cell has — the face wins, which
  /// covers Battleship's coordinate on a covered square, Minesweeper's count
  /// on an uncovered one, Four Corners' answer on a permanently face-up board.
  Widget? _content(Color? tinted, Color ground, {double pad = 4}) {
    if (cell.face case final f?) {
      return Padding(padding: const EdgeInsets.all(6), child: _Face(f));
    }
    if (cell.label case final l?) {
      // Tight constraints, then fit: a FittedBox under a centred container
      // gets LOOSE constraints and sizes to its child, so every label — the
      // B3 a room calls out, the letters of a word search — rendered at
      // fourteen pixels on a TV. Expanded first, it scales the label to the
      // tile, and a long label (a category and its answer) scales down.
      //
      // The colour is picked against the tile it sits on. It used to be
      // white at 60% whatever the tile — readable on a dark cover, INVISIBLE
      // on the white face-up tile every letter game draws: Word Search,
      // Boggle and Scavenger shipped as blank white grids, and their gallery
      // plates passed twice in a row because there was nothing to differ.
      final ink = AppColors.onAccent(tinted ?? ground);
      return SizedBox.expand(
        child: Padding(
          padding: EdgeInsets.all(pad * 2.5),
          child: FittedBox(
            child: Text(
              l,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tinted == null ? ink.withValues(alpha: 0.72) : ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    return null;
  }

  Widget _tile(Color? tinted, Color accent) {
    final ground = _down
        ? const Color(0xFF1A1B26) // raw-canvas: TV stage
        : Colors.white; // raw-canvas: TV stage
    return AnimatedOpacity(
      opacity: _done ? 0.45 : 1,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: tinted ?? ground,
          border: framed
              ? Border.all(color: accent.withValues(alpha: 0.35))
              : null,
          borderRadius: framed ? null : BorderRadius.circular(10),
          // A lit tile glows — the winning line, the pad the pattern is on.
          boxShadow: cell.tint == CellTint.live
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.7),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: _content(tinted, ground),
      ),
    );
  }

  /// A big rounded pad in its slot colour: dim while waiting, full and
  /// glowing while lit. The label (a corner's answer) sits on it in a colour
  /// picked for contrast.
  Widget _pad() {
    final base = cell.slot == 0
        ? const Color(0xFF3A3A46)
        : _slotColor(cell.slot); // raw-canvas: TV stage
    final lit = cell.tint == CellTint.live;
    final fill = lit
        ? base
        : Color.alphaBlend(
            base.withValues(alpha: 0.5),
            const Color(0xFF10100F),
          ); // raw-canvas: TV stage
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: _done ? fill.withValues(alpha: 0.35) : fill,
        borderRadius: BorderRadius.circular(22),
        boxShadow: lit
            ? [BoxShadow(color: base.withValues(alpha: 0.75), blurRadius: 28)]
            : null,
      ),
      alignment: Alignment.center,
      child: cell.label == null
          ? null
          : SizedBox.expand(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: FittedBox(
                  child: Text(
                    cell.label!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: lit
                          ? AppColors.onAccent(base)
                          : Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// A hole in the rack, or a disc in it.
  Widget _hole() {
    final disc = !_down && cell.slot != 0;
    final color = disc
        ? _slotColor(cell.slot)
        : const Color(0xFF10100F); // raw-canvas: TV stage
    final lit = cell.tint == CellTint.live;
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: lit
                ? Border.all(
                    color: Colors.white,
                    width: 3,
                  ) // raw-canvas: TV stage
                : null,
            boxShadow: lit
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.9),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          // A disc has a little inner highlight so it reads as a THING, not
          // a flat dot — one lighter ring, no gradient.
          child: disc
              ? Padding(
                  padding: const EdgeInsets.all(7),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 2,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// Dots, edges and boxes at double resolution, read off the parity of the
  /// cell's position: even/even is a dot, odd/odd a box, the rest edges.
  Widget _latticePiece() {
    final dot = row.isEven && col.isEven;
    final box = row.isOdd && col.isOdd;
    if (box) {
      // Empty until somebody closes it; then its side's colour.
      if (cell.slot == 0) return const SizedBox.expand();
      return Padding(
        padding: const EdgeInsets.all(3),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _slotColor(cell.slot).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
    }
    if (dot) {
      return Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Colors.white70, // raw-canvas: TV stage
            shape: BoxShape.circle,
          ),
        ),
      );
    }
    // An edge: a faint hint of where a line could go, a solid bar once drawn.
    final drawn = cell.state == CellState.shown;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: drawn
              ? Colors
                    .white // raw-canvas: TV stage
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

/// What a cell shows face-up.
///
/// A face is EITHER an emoji or a picture, and the two need different
/// widgets. Drawing every face as Text was fine while the only grid games
/// carried emoji, and shipped Bingo as a board of blank squares the moment
/// one carried `assets/card_games/everyday/04-banana.png` — a file path
/// scaled down to nothing. Memory and Guess Who were one cast away from the
/// same thing.
///
/// The test is the path, not the game: a bundled asset renders through
/// [CardTile] (which degrades to a broken-image glyph rather than throwing),
/// a Storage path through the signed-URL loader, and anything else is a
/// glyph.
class _Face extends StatelessWidget {
  const _Face(this.ref);

  final String ref;

  @override
  Widget build(BuildContext context) {
    if (ref.startsWith('assets/')) return CardTile(image: ref);
    // A person photo lives in Storage and needs a signed URL; an emoji never
    // contains a slash, so this cannot swallow one.
    if (ref.contains('/')) {
      return PersonPhotoNetwork(
        urlOrPath: ref,
        placeholderBuilder: (_) => const ColoredBox(color: Colors.white),
      );
    }
    return FittedBox(
      child: Text(ref, style: const TextStyle(fontSize: 64)),
    );
  }
}
