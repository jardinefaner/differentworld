import 'package:differentworld/features/action_words/mood.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the scale is 1–5 with distinct emojis', () {
    expect(MoodLevel.values.length, 5);
    expect(MoodLevel.values.map((m) => m.value).toList(), [1, 2, 3, 4, 5]);
    expect(MoodLevel.values.map((m) => m.emoji).toSet().length, 5);
    for (final m in MoodLevel.values) {
      expect(m.label, isNotEmpty);
    }
  });

  test('fromValue maps + clamps the out-of-range to the middle', () {
    expect(MoodLevel.fromValue(1), MoodLevel.stormy);
    expect(MoodLevel.fromValue(5), MoodLevel.bright);
    expect(MoodLevel.fromValue(3), MoodLevel.cloudy);
    expect(MoodLevel.fromValue(0), MoodLevel.cloudy); // unknown → middle
    expect(MoodLevel.fromValue(99), MoodLevel.cloudy);
  });
}
