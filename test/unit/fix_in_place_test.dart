// An attention item should be fixable WHERE YOU FOUND IT. These pin which
// kinds qualify — because the tempting mistake is to put an inline control
// on everything, and a fake control in front of a real problem (a photo
// that needs a camera, a room that needs a decision about which child
// leaves) is worse than an honest link away.

import 'package:differentworld/features/readiness/readiness.dart';
import 'package:differentworld/features/readiness/widgets/fix_in_place.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('what can be fixed in place', () {
    test('a yes/no answer can — that is the whole task', () {
      expect(FixInPlace.supports(ReadinessKind.missingConsent), isTrue);
      expect(FixInPlace.supports(ReadinessKind.missingAllergyAnswer), isTrue);
    });

    test('a photo cannot — it needs a camera', () {
      expect(FixInPlace.supports(ReadinessKind.missingPhoto), isFalse);
    });

    test('an over-full room cannot — it needs a decision about children', () {
      expect(FixInPlace.supports(ReadinessKind.roomOverLimit), isFalse);
    });

    test('a missing guardian cannot — a person is more than one field', () {
      expect(FixInPlace.supports(ReadinessKind.missingGuardian), isFalse);
    });

    test('arranging a room cannot — it is a whole instrument', () {
      expect(FixInPlace.supports(ReadinessKind.neverArranged), isFalse);
    });

    test('every kind is decided, none left to chance', () {
      // If a new ReadinessKind is added, this forces a decision about it
      // rather than letting it default to "link away" unnoticed.
      for (final k in ReadinessKind.values) {
        expect(
          FixInPlace.supports(k),
          isA<bool>(),
          reason: '$k must be explicitly in or out',
        );
      }
      expect(ReadinessKind.values.length, 6);
    });
  });
}
