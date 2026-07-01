import 'package:differentworld/features/action_words/verb_skills.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('verb skills catalog', () {
    test('is exactly 60 — five per verb', () {
      expect(kVerbSkills.length, 60);
      expect(kVerbSkills.length, kVerbs.length * kSkillsPerVerb);
    });

    test('every verb has exactly five skills, and every skill maps to a real '
        'verb', () {
      for (final v in kVerbs) {
        expect(
          skillsForVerb(v.id).length,
          kSkillsPerVerb,
          reason: 'verb ${v.id}',
        );
      }
      final verbIds = {for (final v in kVerbs) v.id};
      for (final s in kVerbSkills) {
        expect(verbIds.contains(s.verbId), isTrue, reason: s.id);
      }
    });

    test('every skill name is ONE word', () {
      for (final s in kVerbSkills) {
        expect(s.name.trim().contains(RegExp(r'\s')), isFalse, reason: s.name);
        expect(s.name.isNotEmpty, isTrue);
      }
    });

    test('ids are unique and round-trip through verbSkillById', () {
      final ids = kVerbSkills.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate skill id');
      for (final s in kVerbSkills) {
        expect(verbSkillById(s.id), same(s));
      }
      expect(verbSkillById('carry.lift')?.name, 'Lift');
      expect(verbSkillById('nope.nope'), isNull);
    });

    test('every skill carries how + both anchors', () {
      for (final s in kVerbSkills) {
        expect(s.how.trim().isNotEmpty, isTrue, reason: s.id);
        expect(s.week1.trim().isNotEmpty, isTrue, reason: s.id);
        expect(s.week10.trim().isNotEmpty, isTrue, reason: s.id);
      }
    });

    test('the speed skills are lower-is-better; the rest are higher', () {
      // Faster (fewer seconds) is the win for these.
      const speed = {
        'play.invent',
        'play.recover',
        'spark.start',
        'spark.volunteer',
        'flow.read',
        'flow.transition',
        'flow.redirect',
      };
      for (final s in kVerbSkills) {
        expect(
          s.higherIsBetter,
          !speed.contains(s.id),
          reason: '${s.id} higherIsBetter',
        );
      }
    });

    test('skillsForVerb preserves catalog order', () {
      final carry = skillsForVerb('carry').map((s) => s.name).toList();
      expect(carry, ['Lift', 'Steady', 'Gentle', 'Deliver', 'Endure']);
      expect(skillsForVerb('nope'), isEmpty);
    });

    test('unit labels read right per measure', () {
      expect(SkillMeasureKind.seconds.unit, 'sec');
      expect(SkillMeasureKind.frequency.unit, '/day');
      expect(SkillMeasureKind.rating.unit, '/ 5');
      expect(SkillMeasureKind.count.unit, '');
    });
  });
}
