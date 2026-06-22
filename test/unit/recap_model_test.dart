import 'package:differentworld/features/recap/recap_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('recapDetailsForChild — the privacy scrub', () {
    test(
      "a child's copy never names another child, but keeps their own name "
      '+ the curriculum content',
      () {
        const maya = RecapChildInput(
          subjectId: 's-maya',
          firstName: 'Maya',
          ownNames: {'Maya', 'Rivera'},
          heroName: 'Luna of the Stars',
          // Her own answer happens to name another child:
          answer: 'I played with Sofia and built a fort',
        );
        final details = recapDetailsForChild(
          date: '2026-06-19',
          activities: const ['PE', 'Potions'],
          question: 'What is happiness?',
          // The shared room moment names another child:
          momentNote: 'Maya and Sofia brewed lavender potions',
          child: maya,
          otherNames: const {'Sofia', 'Diego'},
        );

        // Acceptance bar: flatten the whole artifact — NO other child's name.
        expect(details.toString(), isNot(contains('Sofia')));
        expect(details.toString(), isNot(contains('Diego')));

        // Maya's own name + the curriculum content stay.
        final moment = details['moment'] as String;
        expect(moment, contains('Maya'));
        expect(moment, contains('a friend')); // Sofia → "a friend"
        final child = details['child'] as Map;
        expect(child['name'], 'Maya');
        expect(child['hero'], 'Luna of the Stars');
        expect(child['answer'], contains('a friend'));
        expect(child['answer'], isNot(contains('Sofia')));
        expect(details['activities'], const ['PE', 'Potions']);
        expect(details['question'], 'What is happiness?');
      },
    );

    test(
      "stores this child's day photos verbatim — bare paths carry no names, "
      'so the privacy scrub is unaffected',
      () {
        const maya = RecapChildInput(
          subjectId: 's-maya',
          firstName: 'Maya',
          ownNames: {'Maya'},
          // The composer already scoped this list to room moments + Maya's own
          // tagged photos — never another child's. We assert it round-trips.
          photoUrls: ['space/blockA/room1.jpg', 'space/blockA/maya2.jpg'],
        );
        final details = recapDetailsForChild(
          date: '2026-06-19',
          activities: const ['Garden'],
          child: maya,
          otherNames: const {'Sofia'},
        );
        expect(
          details['photos'],
          const ['space/blockA/room1.jpg', 'space/blockA/maya2.jpg'],
        );
        // Paths are not free-text → the flatten-and-scan privacy bar still holds.
        expect(details.toString(), isNot(contains('Sofia')));

        final v = RecapView.fromJson(details);
        expect(v.photos, hasLength(2));
        expect(v.photos.first, 'space/blockA/room1.jpg');
      },
    );

    test('omits empty optional fields', () {
      final d = recapDetailsForChild(
        date: '2026-06-19',
        activities: const [],
        momentNote: '   ',
        child: const RecapChildInput(
          subjectId: 's',
          firstName: 'Ari',
          ownNames: {'Ari'},
        ),
        otherNames: const {},
      );
      expect(d.containsKey('moment'), isFalse);
      expect(d.containsKey('question'), isFalse);
      final child = d['child'] as Map;
      expect(child.containsKey('hero'), isFalse);
      expect(child.containsKey('answer'), isFalse);
      expect(child['name'], 'Ari');
    });
  });

  group('RecapView.fromJson', () {
    test('parses a full recap', () {
      final v = RecapView.fromJson(const {
        'date': '2026-06-19',
        'activities': ['PE', 'Potions'],
        'question': 'What is happiness?',
        'moment': 'We brewed potions',
        'child': {'name': 'Maya', 'hero': 'Luna', 'answer': 'When we share'},
      });
      expect(v.activities, const ['PE', 'Potions']);
      expect(v.childName, 'Maya');
      expect(v.heroName, 'Luna');
      expect(v.answer, 'When we share');
      expect(v.hasChildMoments, isTrue);
    });

    test('tolerates a sparse recap (room day only, no child moments)', () {
      final v = RecapView.fromJson(const {
        'date': '2026-06-19',
        'activities': ['PE'],
        'child': {'name': 'Ari'},
      });
      expect(v.childName, 'Ari');
      expect(v.heroName, isNull);
      expect(v.hasChildMoments, isFalse);
    });
  });
}
