import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every curriculum world has exactly three rules', () {
    final raw = File('assets/curriculum/ten_worlds.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final worldIds = [
      for (final w in decoded['worlds'] as List)
        (w as Map<String, dynamic>)['id'] as String,
    ];
    for (final id in worldIds) {
      expect(kWorldRules[id], isNotNull, reason: 'no rules for $id');
      expect(kWorldRules[id]!.length, 3, reason: '$id needs 3 rules');
    }
  });

  test('every rule tags only real verb ids', () {
    final verbIds = kVerbs.map((v) => v.id).toSet();
    for (final entry in kWorldRules.entries) {
      for (final rule in entry.value) {
        expect(rule.text, isNotEmpty);
        expect(rule.verbs, isNotEmpty);
        for (final v in rule.verbs) {
          expect(
            verbIds.contains(v),
            isTrue,
            reason: '${entry.key} rule references unknown verb "$v"',
          );
        }
      }
    }
  });

  group('ruleForVerbs — the kid claims a rule by their picks', () {
    test('Nature + WAIT → "the slow things outlast"', () {
      final rule = ruleForVerbs('nature', ['wait', 'watch', 'listen']);
      expect(rule?.text, contains('slow things'));
    });

    test('Nature + HELP/ECHO → "everything is connected"', () {
      final rule = ruleForVerbs('nature', ['help', 'echo', 'shine']);
      expect(rule?.text, contains('connected'));
    });

    test('more overlap wins', () {
      // BUILD + CARRY both tag "nothing is wasted" (2 overlaps) vs WAIT (1).
      final rule = ruleForVerbs('nature', ['build', 'carry', 'wait']);
      expect(rule?.text, contains('wasted'));
    });

    test('no overlap → no claimed rule', () {
      expect(ruleForVerbs('nature', ['spark', 'play', 'flow']), isNull);
      expect(ruleForVerbs('unknown-world', ['wait']), isNull);
    });
  });
}
