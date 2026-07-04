import 'package:differentworld/features/action_words/curriculum_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('curriculumActivityName', () {
    test('takes the part before the first colon', () {
      expect(
        curriculumActivityName(
          'Body map: trace your body on butcher paper, label the countries',
        ),
        'Body map',
      );
    });

    test('keeps the whole thing when there is no colon', () {
      expect(curriculumActivityName('Mirror minute'), 'Mirror minute');
    });

    test('truncates an overlong title', () {
      final name = curriculumActivityName('A' * 80);
      expect(name.length, lessThanOrEqualTo(46));
      expect(name.endsWith('…'), isTrue);
    });
  });

  group('curriculumActivityIsOutdoor', () {
    test('detects outdoor prompts', () {
      expect(
        curriculumActivityIsOutdoor('Bug safari: go outside, find a bug'),
        isTrue,
      );
      expect(curriculumActivityIsOutdoor('Planet walk in the yard'), isTrue);
    });

    test('indoor prompts are not flagged', () {
      expect(curriculumActivityIsOutdoor('Body map: trace your body'), isFalse);
      expect(
        curriculumActivityIsOutdoor('Water xylophone: 5 glasses'),
        isFalse,
      );
    });
  });
}
