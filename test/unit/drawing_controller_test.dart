import 'dart:ui';

import 'package:differentworld/shared/widgets/drawing_pad.dart';
import 'package:flutter_test/flutter_test.dart';

/// The drawing engine shared by the kid draw-self screen + the Heroes pad. The
/// rasterise path needs a mounted RepaintBoundary (covered by widget tests); the
/// stroke MODEL is pure and lives here.
void main() {
  test('a stroke is committed on end, and counts as a drawing', () {
    final c = DrawingController();
    expect(c.hasDrawing, isFalse);
    expect(c.canUndo, isFalse);

    c.startStroke(Offset.zero);
    // An open stroke is not yet "a drawing" — only committed strokes count.
    expect(c.hasDrawing, isFalse);
    c
      ..extendStroke(const Offset(10, 10))
      ..endStroke();

    expect(c.strokes, hasLength(1));
    expect(c.strokes.single.points, hasLength(2));
    expect(c.hasDrawing, isTrue);
    expect(c.canUndo, isTrue);
  });

  test('undo removes the last committed stroke; clear empties everything', () {
    final c = DrawingController()
      ..startStroke(Offset.zero)
      ..endStroke()
      ..startStroke(const Offset(5, 5))
      ..endStroke();
    expect(c.strokes, hasLength(2));

    c.undo();
    expect(c.strokes, hasLength(1));

    c
      ..startStroke(const Offset(9, 9)) // an in-progress stroke too
      ..clear();
    expect(c.strokes, isEmpty);
    expect(c.active, isNull);
    expect(c.hasDrawing, isFalse);
  });

  test('the current color + width are captured into the next stroke', () {
    final c = DrawingController()
      ..setColor(const Color(0xFF1E88E5))
      ..setWidth(22)
      ..startStroke(Offset.zero)
      ..endStroke();

    expect(c.strokes.single.color, const Color(0xFF1E88E5));
    expect(c.strokes.single.width, 22);
  });

  test('extend / end with no active stroke are no-ops (no throw)', () {
    final c = DrawingController()
      ..extendStroke(const Offset(1, 1))
      ..endStroke();
    expect(c.strokes, isEmpty);
    expect(c.hasDrawing, isFalse);
  });
}
