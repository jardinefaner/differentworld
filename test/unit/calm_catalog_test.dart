// "What to do instead" (docs/VISION.md 2026-06-19) is a pure reference — pin
// that it's well-formed so an empty feeling never renders a sad blank list.

import 'package:differentworld/features/calm/calm_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every feeling offers at least a couple of things to try', () {
    expect(calmFeelings, isNotEmpty);
    for (final f in calmFeelings) {
      expect(f.actions.length, greaterThanOrEqualTo(2), reason: f.label);
      expect(f.label.trim(), isNotEmpty);
      expect(f.emoji.trim(), isNotEmpty);
    }
  });

  test('feeling ids are unique', () {
    final ids = calmFeelings.map((f) => f.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('the room has agreements', () {
    expect(roomAgreements, isNotEmpty);
  });
}
