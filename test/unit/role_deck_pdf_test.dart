import 'package:differentworld/features/heroes/role_deck_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildRoleDeckPdf produces a real PDF and tolerates emoji input', () async {
    // The animalLabel / title carry emoji + a curly apostrophe — the builder
    // must ASCII-fold them (Helvetica can't render either) without throwing.
    final pdf = await buildRoleDeckPdf(
      cards: const [
        RoleCardPrint(
          title: 'Wallace of the Deep Sea',
          species: 'Midnight Whale 🐳',
          animalLabel: 'Whale 🐳',
          powers: ['Shield 🛡️', 'Breathe underwater'],
          childName: 'Maya',
        ),
        RoleCardPrint(
          title: 'Anna of the Anthill',
          species: 'Golden Ant 🐜',
          animalLabel: 'Ant',
          powers: ['Strength'],
          childName: 'Ari',
        ),
      ],
    );
    expect(pdf, isNotEmpty);
    expect(pdf.length, greaterThan(1000), reason: 'a real multi-card PDF');
    // The PDF magic header.
    expect(String.fromCharCodes(pdf.take(4)), '%PDF');
  });
}
