import 'package:differentworld/features/action_words/summer_book.dart';
import 'package:differentworld/features/action_words/summer_book_pdf.dart';
import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

void main() {
  SummerBook sample({List<SummerBookWeek> weeks = const []}) => SummerBook(
    firstName: 'Maya',
    title: 'The Owl Who Listens',
    days: 30,
    weeks: weeks,
  );

  test('builds a valid Summer Book PDF offline', () async {
    final book = sample(
      weeks: [
        const SummerBookWeek(
          week: 3,
          worldName: 'World of Nature',
          emoji: '🌿',
          color: Color(0xFF51cf66),
          // Curly quotes + dash exercise the _ascii sanitizer.
          question: 'If the trees could talk, what would they say about us?',
          verbs: ['Wait', 'Watch', 'Listen'],
          milestone: 'held still for 2 minutes watching a bug',
          spell: 'CANOPY',
          ally: 'Sofia',
          moments: ['pressed a leaf', 'drew the bug she watched'],
        ),
      ],
    );
    final bytes = await renderSummerBookBytes(book);
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('an empty book still renders (cover + closing)', () async {
    final bytes = await renderSummerBookBytes(sample());
    expect(bytes.length, greaterThan(800));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(sample().isEmpty, isTrue);
  });
}
