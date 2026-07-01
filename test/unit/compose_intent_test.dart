import 'package:differentworld/features/omnibox/compose_intent.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A fixed wall clock so day/time resolution is deterministic.
  // 2026-06-30 is a Tuesday, 10:00 local.
  final now = DateTime(2026, 6, 30, 10);

  group('parseComposeIntent — fires on real schedule intents', () {
    test('field trip fires even without a day (strong kind), day defaults', () {
      final i = parseComposeIntent('field trip to the pond', now: now)!;
      expect(i.kind, BlockKind.fieldTrip);
      expect(i.kindLabel, 'Field trip');
      expect(i.title, 'Pond'); // "field trip", "to", "the" stripped
      expect(i.dayWasExplicit, isFalse);
      expect(i.start.hour, 15); // default afternoon
    });

    test('field trip with weekday + time resolves both', () {
      final i = parseComposeIntent('field trip to the pond friday at 2', now: now)!;
      expect(i.kind, BlockKind.fieldTrip);
      expect(i.title, 'Pond');
      expect(i.start.weekday, DateTime.friday);
      expect(i.start.day, 3); // Fri Jul 3 (next Friday after Tue Jun 30)
      expect(i.start.hour, 14); // "at 2" → afterschool PM bias
      expect(i.timeWasExplicit, isTrue);
    });

    test('activity + tomorrow + explicit pm', () {
      final i = parseComposeIntent('art block tomorrow at 3pm', now: now)!;
      expect(i.kind, BlockKind.onSite);
      expect(i.title, 'Art'); // "block" is filler
      expect(i.emoji, '🎨');
      expect(i.start.day, 1); // Jul 1 (tomorrow)
      expect(i.start.month, 7);
      expect(i.start.hour, 15);
    });

    test('reading circle after lunch → onSite at 1pm', () {
      final i = parseComposeIntent('reading circle after lunch monday', now: now)!;
      expect(i.kind, BlockKind.onSite);
      expect(i.title, 'Reading circle');
      expect(i.start.hour, 13);
      expect(i.start.weekday, DateTime.monday);
    });

    test('closed on a weekday', () {
      final i = parseComposeIntent('closed thursday', now: now)!;
      expect(i.kind, BlockKind.closed);
      expect(i.kindLabel, 'Closed');
      expect(i.title, 'Closed'); // nothing left → falls back to label
      expect(i.start.weekday, DateTime.thursday);
    });

    test('no school friday → closed (strong kind)', () {
      final i = parseComposeIntent('no school friday', now: now)!;
      expect(i.kind, BlockKind.closed);
      expect(i.start.weekday, DateTime.friday);
    });

    test('snack with a colon time → break, keeps the noun as title', () {
      final i = parseComposeIntent('snack at 3:30', now: now)!;
      expect(i.kind, BlockKind.breakBlock);
      expect(i.title, 'Snack');
      expect(i.start.hour, 15);
      expect(i.start.minute, 30);
    });

    test('24h time is respected as-is', () {
      final i = parseComposeIntent('outdoor time at 16:00 wednesday', now: now)!;
      expect(i.kind, BlockKind.onSite);
      expect(i.start.hour, 16);
      expect(i.start.minute, 0);
    });
  });

  group('parseComposeIntent — stays null for non-intents', () {
    test('a plain note-to-self does not fire', () {
      expect(parseComposeIntent("remember to call Devon's mom", now: now), isNull);
    });

    test('note starter wins even with a schedule-ish tail', () {
      expect(parseComposeIntent('remind me about art on friday', now: now), isNull);
    });

    test('a bare activity noun with no when does not fire', () {
      // "art" alone is too weak — could be a note. Needs a when-token.
      expect(parseComposeIntent('art', now: now), isNull);
    });

    test('a bare number is not read as a time / intent', () {
      expect(parseComposeIntent('3 kids out sick', now: now), isNull);
    });

    test('bare "trip" needs a when-token — no hijack of a note', () {
      // "what a trip" / "gear for trip" are notes, not field trips.
      expect(parseComposeIntent('what a trip', now: now), isNull);
      expect(parseComposeIntent('gear for the trip', now: now), isNull);
      // But "zoo trip friday" (bare trip + a day) DOES fire.
      final i = parseComposeIntent('zoo trip friday', now: now)!;
      expect(i.kind, BlockKind.fieldTrip);
      expect(i.start.weekday, DateTime.friday);
    });

    test('a pasted paragraph is too long to be a schedule intent', () {
      final wall = 'art tomorrow at 2 ${'lorem ipsum ' * 40}';
      expect(wall.length, greaterThan(200));
      expect(parseComposeIntent(wall, now: now), isNull);
    });

    test('empty / tiny input is null', () {
      expect(parseComposeIntent('', now: now), isNull);
      expect(parseComposeIntent('hi', now: now), isNull);
    });
  });

  group('parseComposeIntent — never drafts into the past', () {
    // Friday, Jul 3 2026 at 5:12 PM.
    final friPm = DateTime(2026, 7, 3, 17, 12);

    test('a named weekday whose explicit time already passed rolls a week', () {
      final i = parseComposeIntent('art friday 10am', now: friPm)!;
      expect(i.start.weekday, DateTime.friday);
      expect(i.start.day, 10); // next Friday, not today
      expect(i.start.month, 7);
      expect(i.start.hour, 10);
    });

    test('a future same-day weekday is NOT rolled (default time)', () {
      // "art friday" on Friday 5pm: default 3pm is past → rounds up to 5:30pm
      // TODAY (not rolled a week — the user didn\'t name a past clock time).
      final i = parseComposeIntent('art friday', now: friPm)!;
      expect(i.start.day, 3); // still today
      expect(i.start.hour, 17);
      expect(i.start.minute, 30);
    });
  });

  group('parseComposeIntent — weekday resolution', () {
    test('the same weekday as today resolves to TODAY, not next week', () {
      // now is Tuesday; "tuesday" → today.
      final i = parseComposeIntent('art tuesday at 4', now: now)!;
      expect(i.start.day, 30);
      expect(i.start.month, 6);
    });

    test('a past weekday rolls forward to next week', () {
      // now is Tuesday; "monday" → next Monday (Jul 6).
      final i = parseComposeIntent('art monday at 4', now: now)!;
      expect(i.start.day, 6);
      expect(i.start.month, 7);
    });

    test('default time on today rounds up past now, not to a past 3pm', () {
      final late = DateTime(2026, 6, 30, 16, 12); // 4:12pm today
      final i = parseComposeIntent('art today', now: late)!;
      expect(i.start.day, 30);
      // 3pm is past → rounds 4:12 up to the next half hour (4:30).
      expect(i.start.hour, 16);
      expect(i.start.minute, 30);
    });
  });
}
