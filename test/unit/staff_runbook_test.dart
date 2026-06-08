import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/staff/runbook.dart';
import 'package:flutter_test/flutter_test.dart';

/// The staff runbook — every moment of the day must carry all three lanes
/// (lead / helper / if-it-breaks) so a cold substitute can run the next hour.
void main() {
  List<RunbookMoment> load() {
    final raw = File('assets/curriculum/staff_runbook.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final m in decoded['moments'] as List)
        RunbookMoment.fromJson(m as Map<String, dynamic>),
    ];
  }

  test('the runbook covers the day in order with full moments', () {
    final moments = load();
    expect(moments.length, greaterThanOrEqualTo(6));
    for (final m in moments) {
      expect(m.time, isNotEmpty, reason: '${m.name} has no time');
      expect(m.name, isNotEmpty);
      expect(m.emoji, isNotEmpty);
    }
  });

  test('EVERY moment has all three lanes — no helper left guessing', () {
    for (final m in load()) {
      expect(m.lead, isNotEmpty, reason: '${m.name}: no lead lane');
      expect(m.helper, isNotEmpty, reason: '${m.name}: no helper lane');
      expect(
        m.ifItBreaks,
        isNotEmpty,
        reason: '${m.name}: no if-it-breaks lane',
      );
    }
  });

  test('opens on the door greeting and closes on the closing', () {
    final moments = load();
    expect(moments.first.name.toLowerCase(), contains('door'));
    expect(moments.last.name.toLowerCase(), contains('closing'));
  });
}
