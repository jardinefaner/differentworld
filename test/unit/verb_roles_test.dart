import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/verb_roles.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter_test/flutter_test.dart';

/// The verb spine — every one of the 12 canonical verbs must carry its full
/// role: a kid JOB (with a helper script), a 3-level mission (+ guide), and a
/// 3-level staff skill. One vocabulary, three lives — no verb left half-built.
void main() {
  Map<String, VerbRole> load() {
    final raw = File('assets/curriculum/verb_roles.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final roles = decoded['roles'] as Map<String, dynamic>;
    return {
      for (final e in roles.entries)
        e.key: VerbRole.fromJson(e.key, e.value as Map<String, dynamic>),
    };
  }

  test('every canonical verb has a fully-formed role', () {
    final roles = load();
    for (final v in kVerbs) {
      final role = roles[v.id];
      expect(role, isNotNull, reason: '${v.id} has no role');
      expect(role!.jobTitle, isNotEmpty, reason: '${v.id} has no job title');
      expect(role.jobs, isNotEmpty, reason: '${v.id} has no jobs');
    }
  });

  test('every job carries a helper script (exact words to say)', () {
    for (final role in load().values) {
      for (final job in role.jobs) {
        expect(job.job, isNotEmpty, reason: '${role.verbId}: nameless job');
        expect(
          job.helperSays,
          isNotEmpty,
          reason: '${role.verbId} job "${job.job}" has no helper script',
        );
      }
    }
  });

  test('every mission has three levels and a helper guide', () {
    for (final role in load().values) {
      expect(role.mission.level1, isNotEmpty, reason: '${role.verbId} L1');
      expect(role.mission.level2, isNotEmpty, reason: '${role.verbId} L2');
      expect(role.mission.level3, isNotEmpty, reason: '${role.verbId} L3');
      expect(
        role.mission.helperGuide,
        isNotEmpty,
        reason: '${role.verbId} has no helper guide',
      );
    }
  });

  test('every verb has staff skills at levels 1, 2, and 3', () {
    for (final role in load().values) {
      final levels = role.staffSkills.map((s) => s.level).toList()..sort();
      expect(levels, [1, 2, 3], reason: '${role.verbId} staff skill levels');
      for (final s in role.staffSkills) {
        expect(s.skill, isNotEmpty, reason: '${role.verbId} skill name');
        expect(s.desc, isNotEmpty, reason: '${role.verbId} skill desc');
      }
    }
  });
}
