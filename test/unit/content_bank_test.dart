// The content bank proof (docs/CONTENT_BANK.md) — serve-once, de-dupe,
// exhaust. Pure logic; the DB-backed bank will reuse these assertions.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ContentItem item(String kind, String fp) =>
      ContentItem(kind: kind, fingerprint: fp, payload: {'fp': fp});

  group('LocalContentBank', () {
    test('serves each item once, then runs dry', () {
      final bank = LocalContentBank([
        item('k', 'a'),
        item('k', 'b'),
      ]);
      expect(bank.remaining('k'), 2);

      final first = bank.next('k')!;
      final second = bank.next('k')!;
      expect({first.fingerprint, second.fingerprint}, {'a', 'b'});
      expect(bank.next('k'), isNull, reason: 'no repeats');
      expect(bank.remaining('k'), 0);
    });

    test('de-dupes by (kind, fingerprint) at load', () {
      final bank = LocalContentBank([
        item('k', 'dup'),
        item('k', 'dup'),
        item('k', 'other'),
      ]);
      expect(bank.remaining('k'), 2, reason: 'the duplicate is dropped');
    });

    test('take(n) returns up to n unseen and marks them served', () {
      final bank = LocalContentBank([
        item('k', 'a'),
        item('k', 'b'),
        item('k', 'c'),
      ]);
      final round = bank.take('k', 2);
      expect(round, hasLength(2));
      expect(bank.remaining('k'), 1);
      expect(bank.take('k', 5), hasLength(1), reason: 'only one left');
    });

    test('reset re-serves the whole bank', () {
      final bank = LocalContentBank([item('k', 'a')]);
      expect(bank.next('k'), isNotNull);
      expect(bank.next('k'), isNull);
      bank.reset();
      expect(bank.next('k'), isNotNull);
    });

    test('different kinds are independent', () {
      final bank = LocalContentBank([item('x', 'a'), item('y', 'a')]);
      expect(bank.remaining('x'), 1);
      expect(bank.remaining('y'), 1);
      bank.next('x');
      expect(bank.remaining('x'), 0);
      expect(bank.remaining('y'), 1);
    });

    test('the shipped seed bank has this-or-that pairs and categories', () {
      final bank = LocalContentBank.seeded();
      expect(bank.remaining(ContentKind.thisOrThat), greaterThan(8));
      expect(bank.remaining(ContentKind.category), greaterThan(6));
      final pair = bank.next(ContentKind.thisOrThat)!;
      expect(pair.payload['a'], isA<String>());
      expect(pair.payload['b'], isA<String>());
    });
  });
}
