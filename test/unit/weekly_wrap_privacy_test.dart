import 'package:differentworld/features/subjects/weekly_wrap.dart';
import 'package:flutter_test/flutter_test.dart';

/// The weekly wrap is a family-facing artifact (cast to the room, sent home
/// next slice), so it MUST NOT leak another enrolled child's name into this
/// child's keepsake (the family-scrub class — CLAUDE.md). This pins that
/// guarantee on the pure slide builder, the template being
/// summer_book_privacy_test.dart.
void main() {
  test('scrubs other children’s names from captions, keeps the subject’s', () {
    final slides = buildWeeklyWrapSlides(
      childName: 'Owen',
      totalPieces: 2,
      otherNames: {'Sofia', 'Mateo'},
      items: const [
        (
          day: 'MONDAY',
          imagePath: null,
          body: 'Built a fort with Sofia and Mateo',
        ),
        (
          day: 'TUESDAY',
          imagePath: 'student-photos/x.png',
          body: 'Sofia helped me draw this',
        ),
      ],
    );

    final flat = slides
        .map((s) => '${s.eyebrow ?? ''} ${s.title} ${s.subtitle ?? ''}')
        .join(' ');

    expect(flat.contains('Sofia'), isFalse, reason: 'other child name leaked');
    expect(flat.contains('Mateo'), isFalse, reason: 'other child name leaked');
    expect(
      flat.contains('Owen'),
      isTrue,
      reason: "the subject's own name stays",
    );
  });

  test(
    'a photo item keeps its hero imagePath; note-only items render as text',
    () {
      final slides = buildWeeklyWrapSlides(
        childName: 'Lux',
        totalPieces: 2,
        otherNames: const <String>{},
        items: const [
          (day: 'WED', imagePath: 'p/1.png', body: ''),
          (day: 'THU', imagePath: null, body: 'I counted to twenty'),
        ],
      );

      // lead + photo + note + closing
      expect(slides.length, 4);
      expect(slides[1].imagePath, 'p/1.png');
      expect(slides[2].imagePath, isNull);
      expect(slides[2].title, 'I counted to twenty');
    },
  );

  test('an empty note-only item is dropped (no blank slide)', () {
    final slides = buildWeeklyWrapSlides(
      childName: 'Ada',
      totalPieces: 0,
      otherNames: const <String>{},
      items: const [(day: 'FRI', imagePath: null, body: '   ')],
    );
    // just lead + closing — the empty item contributes nothing
    expect(slides.length, 2);
  });
}
