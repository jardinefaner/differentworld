import 'package:differentworld/features/action_words/week_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isEmpty only when every noticed field is blank', () {
    expect(const WeekLog(week: 3).isEmpty, isTrue);
    expect(const WeekLog(week: 3, milestone: 'held still 2 min').isEmpty,
        isFalse);
    expect(const WeekLog(week: 3, spell: 'CANOPY').isEmpty, isFalse);
    expect(const WeekLog(week: 3, ally: 'Sofia').isEmpty, isFalse);
  });
}
