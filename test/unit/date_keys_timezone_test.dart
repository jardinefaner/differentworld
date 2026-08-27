// Every timestamp in this app is stored as a UTC ISO string, so
// `DateTime.tryParse` of a stored value returns a UTC DateTime. Reading
// `.hour` off one shows the room a time shifted by the whole UTC offset —
// which is what "add a block's time is wrong" turned out to be.
//
// These pin the formatters against a PARSED STORED VALUE rather than a
// hand-built local DateTime, because a local fixture passes either way and
// would have caught nothing.

import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('timeOfDay', () {
    test('renders a stored UTC timestamp in local time', () {
      final stored = DateTime.tryParse('2026-08-26T22:45:00.000Z')!;
      expect(stored.isUtc, isTrue, reason: 'the fixture must be UTC');
      expect(timeOfDay(stored), timeOfDay(stored.toLocal()));
    });

    test('is unchanged for a DateTime that is already local', () {
      final local = DateTime(2026, 8, 26, 16, 30);
      expect(timeOfDay(local), '16:30');
    });

    test('agrees with the components a person would read off a clock', () {
      final local = DateTime(2026, 8, 26, 9, 5);
      expect(timeOfDay(local.toUtc()), '09:05');
    });
  });

  group('dateKey', () {
    test('a stored timestamp lands on its LOCAL date', () {
      // The midnight-crossing case: whichever side of UTC the machine is
      // on, the key must match the local calendar day, because that is what
      // attendance_date and the sync-rule date filters mean.
      final stored = DateTime.tryParse('2026-08-26T23:30:00.000Z')!;
      expect(dateKey(stored), dateKey(stored.toLocal()));
    });

    test('is unchanged for a local DateTime', () {
      expect(dateKey(DateTime(2026, 8, 26, 23, 30)), '2026-08-26');
    });

    test('a UTC round-trip does not move the day', () {
      final local = DateTime(2026, 1, 1, 0, 30);
      expect(dateKey(local.toUtc()), '2026-01-01');
    });
  });
}
