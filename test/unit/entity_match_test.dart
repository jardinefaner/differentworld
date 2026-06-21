import 'package:differentworld/features/entities/entity_match.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:flutter_test/flutter_test.dart';

/// The autotagger's brain is a PURE function — these tests pin its correctness
/// and, critically, its privacy guarantee (the family-scope exclude is the
/// link-layer analog of `scrubOtherNames`: another child's name must never
/// become a live link on a keepsake that isn't theirs).
void main() {
  EntityRef subj(String id) =>
      EntityRef(kind: EntityKind.subject, id: id, label: id);
  EntityRef act(String id) =>
      EntityRef(kind: EntityKind.activity, id: id, label: id);

  group('findEntityMatches', () {
    test('matches a known proper-noun name', () {
      const text = 'Sofia built a fort';
      final m = findEntityMatches(text, [
        EntityMatchTerm(text: 'Sofia', ref: subj('s1'), properNounOnly: true),
      ]);
      expect(m, hasLength(1));
      expect(m.single.ref.id, 's1');
      expect(text.substring(m.single.start, m.single.end), 'Sofia');
    });

    test('proper-noun gate skips a lowercase common-word collision', () {
      // A child/teacher called "Will" must not light up every "will".
      final m = findEntityMatches('she will go outside', [
        const EntityMatchTerm(
          text: 'Will',
          ref: EntityRef(kind: EntityKind.member, id: 'm1', label: 'Will'),
          properNounOnly: true,
        ),
      ]);
      expect(m, isEmpty);
    });

    test('longest match wins on overlap', () {
      final m = findEntityMatches('they had free play today', [
        EntityMatchTerm(text: 'play', ref: act('a-play')),
        EntityMatchTerm(text: 'free play', ref: act('a-free-play')),
      ]);
      expect(m, hasLength(1));
      expect(m.single.ref.id, 'a-free-play');
    });

    test('respects word boundaries (no substring matches)', () {
      final m = findEntityMatches('at the playground', [
        EntityMatchTerm(text: 'play', ref: act('a-play')),
      ]);
      expect(m, isEmpty);
    });

    test('returns hits in reading order', () {
      final m = findEntityMatches('Mateo then Sofia', [
        EntityMatchTerm(text: 'Sofia', ref: subj('sofia'), properNounOnly: true),
        EntityMatchTerm(text: 'Mateo', ref: subj('mateo'), properNounOnly: true),
      ]);
      expect(m.map((x) => x.ref.id), ['mateo', 'sofia']);
    });

    test('family-scope exclude never links another child', () {
      final sofia = subj('sofia');
      final mateo = subj('mateo');
      final terms = [
        EntityMatchTerm(text: 'Sofia', ref: sofia, properNounOnly: true),
        EntityMatchTerm(text: 'Mateo', ref: mateo, properNounOnly: true),
      ];
      // A keepsake FOR Sofia: Mateo (another child) must NOT become a link,
      // even though his name is in the prose.
      final m = findEntityMatches(
        'Sofia and Mateo built a fort',
        terms,
        exclude: {mateo},
      );
      expect(m.map((x) => x.ref.id), ['sofia']);
      expect(m.any((x) => x.ref.id == 'mateo'), isFalse);
    });
  });
}
