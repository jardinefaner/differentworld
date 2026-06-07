import 'package:differentworld/features/action_words/summer_book.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

/// The buddy-system Red Team fix: a child's Summer Book is the family
/// keepsake — it leaves the building. No OTHER child's name may appear in
/// it. The staff Book screen keeps full names (canSeeSubject-gated); only
/// the EXPORT path runs [anonymizeSummerBook].
void main() {
  group('scrubOtherNames', () {
    test('replaces another child name with "a friend"', () {
      expect(
        scrubOtherNames('worked with Sofia on the sound map', {'Sofia'}),
        'worked with a friend on the sound map',
      );
    });

    test('is case-insensitive', () {
      expect(scrubOtherNames('SOFIA helped', {'Sofia'}), 'a friend helped');
      expect(scrubOtherNames('played w/ sofia', {'Sofia'}), 'played w/ a friend');
    });

    test('matches on word boundaries — never a substring of another word', () {
      // "Sofia" must not fire inside "sofiance" or "Sofiana".
      expect(scrubOtherNames('the sofiana plant', {'Sofia'}), 'the sofiana plant');
      // But a trailing-punctuation occurrence still scrubs.
      expect(scrubOtherNames('with Sofia!', {'Sofia'}), 'with a friend!');
    });

    test('scrubs the possessive form too ("Sofia\'s" → "a friend\'s")', () {
      expect(scrubOtherNames("Sofia's idea grew", {'Sofia'}), "a friend's idea grew");
    });

    test('scrubs every name in the set', () {
      expect(
        scrubOtherNames('Sofia and Aiden built a fort', {'Sofia', 'Aiden'}),
        'a friend and a friend built a fort',
      );
    });

    test('leaves text alone when the set is empty (staff path)', () {
      expect(scrubOtherNames('worked with Sofia', {}), 'worked with Sofia');
    });

    test('ignores 1-char names (would over-match)', () {
      expect(scrubOtherNames('a cat sat', {'a'}), 'a cat sat');
    });
  });

  group('anonymizeSummerBook', () {
    SummerBook fixture() => const SummerBook(
          firstName: 'Mateo',
          title: 'The Owl Who Listens',
          days: 28,
          weeks: [
            SummerBookWeek(
              week: 3,
              worldName: 'World of Nature',
              emoji: '🌿',
              color: Color(0xFF4CAF50),
              question: 'What does the world need from us?',
              verbs: ['Notice', 'Protect'],
              milestone: 'Mateo taught Sofia how to plant the seed',
              spell: 'crece', // a vocab word — must survive
              ally: 'worked with Sofia on the sound map',
              moments: [
                'Sofia and Aiden built a fort with Mateo',
                'quietly watered the bean all on their own',
              ],
            ),
          ],
        );

    test('drops every other-child name across milestone, ally, and moments', () {
      final safe = anonymizeSummerBook(fixture(), {'Sofia', 'Aiden'});
      final w = safe.weeks.single;
      expect(w.milestone, 'Mateo taught a friend how to plant the seed');
      expect(w.ally, 'worked with a friend on the sound map');
      expect(w.moments.first, 'a friend and a friend built a fort with Mateo');
      // The unrelated moment is untouched.
      expect(w.moments[1], 'quietly watered the bean all on their own');
    });

    test('the child OWN name and curriculum content survive', () {
      final safe = anonymizeSummerBook(fixture(), {'Sofia', 'Aiden'});
      final w = safe.weeks.single;
      expect(safe.firstName, 'Mateo');
      expect(w.milestone, contains('Mateo')); // their own name stays
      expect(w.spell, 'crece'); // the spell is never scrubbed
      expect(w.worldName, 'World of Nature');
      expect(w.verbs, ['Notice', 'Protect']);
    });

    test('ACCEPTANCE: an exported book contains NO other child name anywhere', () {
      final safe = anonymizeSummerBook(fixture(), {'Sofia', 'Aiden'});
      // Flatten every rendered string the family could see.
      final rendered = [
        safe.firstName,
        safe.title,
        for (final w in safe.weeks) ...[
          w.worldName,
          w.question,
          w.milestone,
          w.spell,
          w.ally,
          ...w.verbs,
          ...w.moments,
        ],
      ].join('\n').toLowerCase();
      expect(rendered.contains('sofia'), isFalse, reason: 'leaked Sofia');
      expect(rendered.contains('aiden'), isFalse, reason: 'leaked Aiden');
    });

    test('empty name set is a no-op (staff rendering keeps full names)', () {
      final same = anonymizeSummerBook(fixture(), {});
      expect(same.weeks.single.ally, 'worked with Sofia on the sound map');
    });
  });
}
