import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/worksheet_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<CurriculumWorld> loadWorlds() {
    final raw = File('assets/curriculum/ten_worlds.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final w in decoded['worlds'] as List)
        CurriculumWorld.fromJson(w as Map<String, dynamic>),
    ];
  }

  test('builds a single-world worksheet PDF offline', () async {
    final worlds = loadWorlds();
    final bytes = await renderWorksheetsBytes(
      [worlds.first],
      heading: 'Week 1 — Worksheets',
    );
    expect(bytes.length, greaterThan(1000));
    // Valid PDF header.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('builds the all-worlds packet (every activity, no throw)', () async {
    final worlds = loadWorlds();
    final bytes = await renderWorksheetsBytes(
      worlds,
      heading: 'If You Built a World — Worksheets',
    );
    expect(bytes.length, greaterThan(5000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
