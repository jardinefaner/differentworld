import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/staff/staff_ladder.dart';
import 'package:flutter_test/flutter_test.dart';

/// The staff ladder — four rungs, least → most responsibility, each with what
/// it can do and what it can't do YET (the next thing to grow into).
void main() {
  List<StaffRole> load() {
    final raw = File('assets/curriculum/staff_roles.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return [
      for (final r in decoded['roles'] as List)
        StaffRole.fromJson(r as Map<String, dynamic>),
    ];
  }

  test('the ladder runs Shadow → Extra Hands → Co-Pilot → Conductor', () {
    final ids = load().map((r) => r.id).toList();
    expect(ids, ['shadow', 'hand', 'voice', 'lead']);
  });

  test('every rung has a can-do list; all but the top has a not-yet', () {
    final roles = load();
    for (final r in roles) {
      expect(r.name, isNotEmpty, reason: '${r.id} name');
      expect(r.emoji, isNotEmpty);
      expect(r.desc, isNotEmpty, reason: '${r.id} desc');
      expect(r.canDo, isNotEmpty, reason: '${r.id} can-do');
    }
    // Lower rungs have a "not yet" frontier; the Conductor's is the honest
    // "nothing is off-limits — but ask for help" note (still present).
    for (final r in roles) {
      expect(r.cantDo, isNotEmpty, reason: '${r.id} not-yet');
    }
  });

  test('the Conductor can run the full day solo', () {
    final lead = load().firstWhere((r) => r.id == 'lead');
    expect(
      lead.canDo.any((c) => c.toLowerCase().contains('full day')),
      isTrue,
    );
  });
}
