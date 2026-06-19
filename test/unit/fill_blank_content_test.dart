// Fill-in-the-blank templates (docs/VISION.md 2026-06-19) carry `{0}`, `{1}`…
// placeholders + a parallel `blanks` prompt list. If they ever drift (a blank
// with no placeholder, or a placeholder with no prompt) the reveal renders a
// stray "___" or a prompt the room never gets asked. Pin the integrity.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fills = curatedSeeds
      .where((i) => i.kind == ContentKind.fillBlank)
      .toList();

  test('there are fill-in-the-blank templates', () {
    expect(fills, isNotEmpty);
  });

  test('every template’s placeholders are 0..n-1 with a prompt each', () {
    final re = RegExp(r'\{(\d+)\}');
    for (final item in fills) {
      final template = item.payload['template']! as String;
      final blanks = item.payload['blanks']! as List;
      final indices = re
          .allMatches(template)
          .map((m) => int.parse(m.group(1)!))
          .toSet();
      expect(indices, isNotEmpty, reason: template);
      final maxIdx = indices.reduce((a, b) => a > b ? a : b);
      // No gaps: exactly {0, 1, …, maxIdx}.
      expect(
        indices,
        equals({for (var i = 0; i <= maxIdx; i++) i}),
        reason: 'placeholder gap in: $template',
      );
      // One prompt per blank.
      expect(
        blanks.length,
        maxIdx + 1,
        reason: 'blank count ≠ placeholders in: $template',
      );
    }
  });
}
