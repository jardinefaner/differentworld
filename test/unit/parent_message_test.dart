// Pins the parent-message generator (the brief's Send screen).

import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/parent_message.dart';
import 'package:flutter_test/flutter_test.dart';

ActionWordsDay _day(
  List<String> picks, {
  String? note,
  String? word,
  String? worldName,
}) =>
    ActionWordsDay(
      entry: null,
      verbPicks: picks,
      done: const {},
      note: note,
      wordOfDay: word,
      worldName: worldName,
    );

void main() {
  group('buildParentMessage', () {
    test('a full named-world day reads the brief shape', () {
      final msg = buildParentMessage(
        childName: 'Maya',
        day: _day(
          ['watch', 'spark', 'shine'], // Eagle
          word: 'curious',
          note: 'Great focus today.',
        ),
      );
      expect(msg, contains('Maya was 🦅 Eagle today.'));
      expect(msg, contains('They practiced watch, spark, shine.'));
      expect(msg, contains('Word of the day: curious.'));
      expect(msg, contains('Note: Great focus today.'));
      expect(msg, contains('Ask at dinner:'));
    });

    test('omits word-of-day and note lines when absent', () {
      final msg =
          buildParentMessage(childName: 'Ben', day: _day(['watch', 'spark', 'shine']));
      expect(msg, isNot(contains('Word of the day')));
      expect(msg, isNot(contains('Note:')));
      expect(msg, contains('Ben was 🦅 Eagle today.'));
    });

    test('a fresh unnamed world still gives a dinner question', () {
      final msg = buildParentMessage(
        childName: 'Cal',
        day: _day(['carry', 'echo', 'solve']),
      );
      expect(msg, contains('Cal discovered a brand-new world today.'));
      expect(msg, contains('Ask at dinner:'));
    });

    test('a fresh NAMED world uses the chosen name', () {
      final msg = buildParentMessage(
        childName: 'Dot',
        day: _day(['carry', 'echo', 'solve'], worldName: 'Phoenix'),
      );
      expect(msg, contains('Dot was 🌟 Phoenix today.'));
    });
  });
}
