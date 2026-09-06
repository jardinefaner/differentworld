import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:flutter/material.dart';

/// Draws a [StageShape]. ONE renderer per shape, shared by every game that
/// describes itself that way.
///
/// This is the half of the shape protocol that makes it worth doing. Reveal
/// the Picture and Memory both hand over a `grid`, and this widget draws both
/// without knowing either exists — so a receiver on an older build can show a
/// grid game shipped after it, instead of "this session needs a newer version".
///
/// A raw canvas: this is the TV, hardcoded dark per docs/THEME_ADHERENCE.md.
class ShapeStageView extends StatelessWidget {
  const ShapeStageView({required this.shape, this.onPick, super.key});

  final StageShape shape;

  /// Tap a cell. Null on the receiver (the room does not touch the TV) and
  /// set on the phone, where the board IS the instrument.
  final void Function(int index)? onPick;

  @override
  Widget build(BuildContext context) => switch (shape.kind) {
    ShapeKind.grid => _Grid(shape: shape, onPick: onPick),
  };
}

class _Grid extends StatelessWidget {
  const _Grid({required this.shape, this.onPick});

  final StageShape shape;
  final void Function(int index)? onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white, // raw-canvas: TV stage
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (shape.title != null || shape.note != null)
            const SizedBox(height: 16),
          Flexible(
            child: AspectRatio(
              aspectRatio: shape.cols / shape.rows,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (shape.behind case final b?)
                      _Behind(b, isImage: shape.behindIsImage),
                    Column(
                      children: [
                        for (var r = 0; r < shape.rows; r++)
                          Expanded(
                            child: Row(
                              children: [
                                for (var c = 0; c < shape.cols; c++)
                                  Expanded(
                                    child: _cellAt(r * shape.cols + c),
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
        ],
      ),
    );
  }

  Widget _cellAt(int i) {
    if (i >= shape.cells.length) return const SizedBox.shrink();
    final cell = shape.cells[i];
    // A shown cell over a shared picture must be a HOLE, not a tile — the
    // point is to see through to the picture underneath.
    final seeThrough = cell.state != CellState.hidden && shape.behind != null;
    return Padding(
      padding: EdgeInsets.all(shape.behind == null ? 4 : 0),
      child: GestureDetector(
        // A resolved or already-open cell is not a target; without this a tap
        // through a lifted tile re-sends a pick for a cell already open.
        onTap: cell.state == CellState.hidden ? () => onPick?.call(i) : null,
        child: seeThrough
            ? const SizedBox.expand()
            : _Cell(cell: cell, framed: shape.behind != null),
      ),
    );
  }
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

class _Cell extends StatelessWidget {
  const _Cell({required this.cell, required this.framed});

  final ShapeCell cell;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = Theme.of(context).extension<AppColors>();
    final accent = scheme.primary;
    final down = cell.state == CellState.hidden;
    final done = cell.state == CellState.done;
    // The tint decides the FACE colour, not the state — a cell can be face-up
    // and still be telling the room it was wrong.
    final tinted = switch (cell.tint) {
      CellTint.none => null,
      CellTint.right => app?.growth ?? scheme.primary,
      CellTint.close => scheme.tertiary,
      CellTint.wrong => scheme.error,
      CellTint.live => accent,
    };
    return AnimatedOpacity(
      opacity: done ? 0.45 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color:
              tinted ??
              (down
                  ? const Color(0xFF1A1B26) // raw-canvas: TV stage
                  : Colors.white), // raw-canvas: TV stage
          border: framed
              ? Border.all(color: accent.withValues(alpha: 0.35))
              : null,
          borderRadius: framed ? null : BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        // A label shows whenever there is no FACE to show instead — which
        // covers all three uses without the renderer knowing the games:
        // Battleship's coordinate on a covered square, Minesweeper's count on
        // an uncovered one, Four Corners' room-position on a permanently
        // face-up board. Keying it to "face down" only served the first.
        child: cell.face == null
            ? (cell.label == null
                  ? null
                  : FittedBox(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          cell.label!,
                          style: TextStyle(
                            color: tinted == null
                                ? Colors.white.withValues(alpha: 0.45)
                                : AppColors.onAccent(tinted),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ))
            : (cell.face == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.all(6),
                      child: _Face(cell.face!),
                    )),
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
