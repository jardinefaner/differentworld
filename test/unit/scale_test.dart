import 'package:differentworld/shared/widgets/scale_bar.dart';
import 'package:flutter_test/flutter_test.dart';

/// SCALE — the eleventh primitive. A position on a bounded continuum + its
/// change. The fraction clamps; the delta is the meaningful part.
void main() {
  test('fraction is the clamped 0..1 position', () {
    expect(const Scale(value: 5, max: 10).fraction, 0.5);
    expect(const Scale(value: 0, max: 10).fraction, 0.0);
    expect(const Scale(value: 10, max: 10).fraction, 1.0);
    // Over/under the bounds clamp, never overflow the bar.
    expect(const Scale(value: 99, max: 10).fraction, 1.0);
    expect(const Scale(value: -5, max: 10).fraction, 0.0);
  });

  test('a non-zero min shifts the continuum', () {
    expect(
      const Scale(value: 6, min: 1, max: 10).fraction,
      closeTo(0.555, 0.01),
    );
  });

  test('a degenerate range never divides by zero', () {
    expect(const Scale(value: 4, max: 0).fraction, 0.0);
    expect(const Scale(value: 4, min: 5, max: 5).fraction, 0.0);
  });

  test('delta is the change since the previous reading, or null', () {
    expect(const Scale(value: 47, previous: 34).delta, 13);
    expect(const Scale(value: 30, previous: 41).delta, -11);
    expect(const Scale(value: 5).delta, isNull);
  });
}
