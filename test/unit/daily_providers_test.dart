// The Daily ritual picks the day's Question / Quote / Mission DETERMINISTICALLY
// (docs/VISION.md 2026-06-19) so the whole room shares one prompt and it rotates
// across days — no randomness. Pin that contract.

import 'package:differentworld/features/daily/daily_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dailyIndexFor is stable for the same date', () {
    expect(dailyIndexFor('2026-06-19'), dailyIndexFor('2026-06-19'));
  });

  test('dailyIndexFor advances by exactly 1 each day (rotates)', () {
    final a = dailyIndexFor('2026-06-19');
    final b = dailyIndexFor('2026-06-20');
    expect(b - a, 1);
  });

  test('different dates pick different days', () {
    expect(
      dailyIndexFor('2026-06-19'),
      isNot(dailyIndexFor('2026-06-26')),
    );
  });

  test('an unparseable date falls back to 0 (never throws)', () {
    expect(dailyIndexFor('not-a-date'), 0);
  });
}
