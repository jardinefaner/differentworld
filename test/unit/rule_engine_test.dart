// The rule-runtime seed proof (docs/SEMANTIC_GRAPH.md §3).
//
// Shows the live-block auto-tag — designed in LIVE_BLOCK_CONTEXT.md and
// otherwise destined to be hardcoded — expressed as DATA and producing
// the identical result through the evaluator. Plus: indexing is real (an
// unrelated event never touches the rule), the closed condition
// vocabulary composes, and a runaway rule is capped.

import 'package:differentworld/features/runtime/noun_rule.dart';
import 'package:differentworld/features/runtime/rule_engine.dart';
import 'package:differentworld/features/runtime/rules/live_block_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleEngine — the live-block auto-tag as data', () {
    test('block live → entry tagged to it (reproduces the hardcoded path)',
        () {
      final engine = RuleEngine([liveBlockAutoTag]);
      final world = entryCreatedWorld(entryId: 'e1', liveBlockId: 'b1');

      final effects = engine.fire(entryCreated, world);

      expect(effects, [
        (
          targetType: 'Entry',
          targetId: 'e1',
          path: 'scheduleBlockId',
          value: 'b1',
        ),
      ]);
      // Applying it sets exactly what the hardcoded path would.
      expect(applyEffects(world.subject, effects)['scheduleBlockId'], 'b1');
    });

    test('no block live → no effect, tag stays null (honest null)', () {
      final engine = RuleEngine([liveBlockAutoTag]);
      final world = entryCreatedWorld(entryId: 'e1');

      final effects = engine.fire(entryCreated, world);

      expect(effects, isEmpty);
      expect(applyEffects(world.subject, effects)['scheduleBlockId'], isNull);
    });

    test('indexed: only the matching trigger evaluates the rule', () {
      final unrelated = RuleEngine([liveBlockAutoTag])
        ..fire(
          const Trigger(nounType: 'Attendance', event: 'marked'),
          entryCreatedWorld(entryId: 'e1', liveBlockId: 'b1'),
        );
      expect(
        unrelated.rulesEvaluated,
        0,
        reason: 'Attendance/marked must not touch an Entry/created rule',
      );

      final matching = RuleEngine([liveBlockAutoTag])
        ..fire(
          entryCreated,
          entryCreatedWorld(entryId: 'e1', liveBlockId: 'b1'),
        );
      expect(matching.rulesEvaluated, 1);
    });
  });

  group('closed condition vocabulary', () {
    test('Exists / Eq / And / Not compose', () {
      const world = World(
        subject: Noun('Entry', 'e1', {'kind': 'observation'}),
        context: {
          'liveBlock': Noun('ScheduleBlock', 'b1', {'status': 'planned'}),
        },
      );

      expect(const Exists('liveBlock').eval(world), isTrue);
      expect(const Exists('nope').eval(world), isFalse);
      expect(const Eq('subject', 'kind', 'observation').eval(world), isTrue);
      expect(const Eq('liveBlock', 'status', 'planned').eval(world), isTrue);
      expect(
        const And([
          Exists('liveBlock'),
          Eq('subject', 'kind', 'observation'),
        ]).eval(world),
        isTrue,
      );
      expect(const Not(Exists('nope')).eval(world), isTrue);
    });
  });

  group('safety', () {
    test('effect budget caps a runaway rule', () {
      final greedy = Rule(
        id: 'greedy',
        when: entryCreated,
        actions: List.generate(
          100,
          (i) => SetProp(
            targetRef: 'subject',
            path: 'p$i',
            fromRef: 'liveBlock',
            fromPath: 'id',
          ),
        ),
      );
      final engine = RuleEngine([greedy]);

      final effects = engine.fire(
        entryCreated,
        entryCreatedWorld(entryId: 'e1', liveBlockId: 'b1'),
        budget: 8,
      );

      expect(effects, hasLength(8));
    });
  });
}
