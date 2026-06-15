import 'package:differentworld/features/family/welcome_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Smoke tests for the first-day welcome PDF — it must produce a valid,
/// non-empty PDF both WITH a real invite QR and WITHOUT one (the offline /
/// no-capability path, where the page still prints minus the QR).
void main() {
  test('builds a valid PDF with the invite QR + world + facts', () async {
    final bytes = await buildWelcomePdf(
      programName: 'Sunny Days',
      childFirstName: 'Maya',
      facts: const [
        (label: 'Room', value: 'Bears Den · 5–7'),
        (label: 'Pickup by', value: '6:00 PM'),
      ],
      worldName: 'Through My Eyes',
      dinnerQuestion: 'What did you notice today?',
      inviteUrl: 'https://differentworld.app/invite/ABCD-1234',
      inviteCode: 'ABCD-1234',
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-'); // PDF magic header
  });

  test('builds without an invite (no QR) — still a valid PDF', () async {
    final bytes = await buildWelcomePdf(
      programName: 'Sunny Days',
      childFirstName: 'Sam',
      facts: const [],
    );
    expect(bytes.lengthInBytes, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
