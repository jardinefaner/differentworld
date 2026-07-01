import 'package:differentworld/features/action_words/widgets/day_arc_strip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dayArcNarrative', () {
    test('one line per block, aligned to the input', () {
      expect(dayArcNarrative([0.25, 0.6, 0.9, 0.4, 0.18]).length, 5);
    });

    test('first opens, last closes', () {
      final n = dayArcNarrative([0.25, 0.6, 0.18]);
      expect(n.first, contains('Opening'));
      expect(n.last, contains('Closing'));
    });

    test('a local peak reads as the high point', () {
      // index 2 (0.9) is a peak: >= 0.7 and >= both neighbours.
      final n = dayArcNarrative([0.2, 0.5, 0.9, 0.5, 0.2]);
      expect(n[2].toLowerCase(), contains('high point'));
    });

    test('rising reads as building, falling as easing', () {
      final n = dayArcNarrative([0.2, 0.5, 0.9, 0.6, 0.2]);
      expect(n[1].toLowerCase(), contains('building')); // 0.2 → 0.5
      expect(n[3].toLowerCase(), contains('easing')); // 0.9 → 0.6
    });

    test('empty + single are safe', () {
      expect(dayArcNarrative(const []), isEmpty);
      expect(dayArcNarrative(const [0.5]).length, 1);
    });
  });
}
