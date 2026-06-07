import 'package:differentworld/features/action_words/skills.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog: unique ids, each with a how', () {
    final ids = kSkills.map((s) => s.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final s in kSkills) {
      expect(s.emoji, isNotEmpty);
      expect(s.name, isNotEmpty);
      expect(s.how, isNotEmpty);
    }
  });

  test('skillById round-trips + null-safe', () {
    expect(skillById(null), isNull);
    expect(skillById('nope'), isNull);
    for (final s in kSkills) {
      expect(skillById(s.id), same(s));
    }
  });

  test('skillForDay is deterministic per calendar day + rotates', () {
    final a1 = skillForDay(DateTime(2026, 7, 14, 9));
    final a2 = skillForDay(DateTime(2026, 7, 14, 17)); // same day, diff time
    expect(a1, same(a2));
    // Across a full cycle of days we hit every skill at least once.
    final hit = <String>{};
    for (var d = 0; d < kSkills.length; d++) {
      hit.add(skillForDay(DateTime(2026, 7, 2).add(Duration(days: d))).id);
    }
    expect(hit.length, kSkills.length);
  });
}
