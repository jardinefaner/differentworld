import 'package:differentworld/features/action_words/block_run.dart';
import 'package:differentworld/features/action_words/routine_script_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyRoutine', () {
    test('maps titles to routine families', () {
      expect(
        classifyRoutine('on_site', 'Arrival & check-in'),
        RoutineKind.arrival,
      );
      expect(classifyRoutine('break', 'Snack'), RoutineKind.meal);
      expect(classifyRoutine('break', 'Rest / quiet time'), RoutineKind.rest);
      expect(classifyRoutine('on_site', 'Transition'), RoutineKind.transition);
      expect(classifyRoutine('on_site', 'Morning circle'), RoutineKind.welcome);
      expect(
        classifyRoutine('on_site', 'Free play outside'),
        RoutineKind.freePlay,
      );
      expect(classifyRoutine('on_site', 'Open studio'), isNull);
    });

    test('a closed block is pickup even without a pickup keyword', () {
      expect(classifyRoutine('closed', 'Wrap up'), RoutineKind.pickup);
      expect(classifyRoutine('on_site', 'Pickup'), RoutineKind.pickup);
    });

    test('earlier families win the precedence', () {
      // "play" would match freePlay, but an arrival title hits arrival first.
      expect(classifyRoutine('on_site', 'Arrival'), RoutineKind.arrival);
    });
  });

  group('defaultRoutineScript', () {
    test('every routine has a non-empty default', () {
      for (final r in RoutineKind.values) {
        expect(defaultRoutineScript(r).steps, isNotEmpty, reason: r.name);
      }
    });

    test('blockRunScript delegates to the default (field-wise)', () {
      final a = blockRunScript('on_site', 'Arrival')!;
      final d = defaultRoutineScript(RoutineKind.arrival);
      expect(a.steps, d.steps);
      expect(a.tools, d.tools);
      expect(blockRunScript('on_site', 'Open studio'), isNull);
    });
  });

  group('encode/decode overrides', () {
    test('round-trips a map of overrides', () {
      final map = <RoutineKind, BlockRunScript>{
        RoutineKind.arrival: (steps: ['Greet at door'], tools: ['sign-in']),
        RoutineKind.transition: (
          steps: ['Eyes up', 'Breathe'],
          tools: const <String>[],
        ),
      };
      final restored = decodeRoutineScripts(encodeRoutineScripts(map));
      expect(restored.length, 2);
      expect(restored[RoutineKind.arrival]!.steps, ['Greet at door']);
      expect(restored[RoutineKind.arrival]!.tools, ['sign-in']);
      expect(restored[RoutineKind.transition]!.steps, ['Eyes up', 'Breathe']);
      expect(restored[RoutineKind.transition]!.tools, isEmpty);
    });

    test('decode is null/garbage safe', () {
      expect(decodeRoutineScripts(null), isEmpty);
      expect(decodeRoutineScripts(''), isEmpty);
      expect(decodeRoutineScripts('not json'), isEmpty);
      expect(decodeRoutineScripts('[1,2,3]'), isEmpty); // a list, not a map
    });

    test('unknown routine keys are dropped', () {
      const raw =
          '{"nonsense":{"steps":["x"],"tools":[]},'
          '"arrival":{"steps":["y"],"tools":[]}}';
      final restored = decodeRoutineScripts(raw);
      expect(restored.keys, [RoutineKind.arrival]);
      expect(restored[RoutineKind.arrival]!.steps, ['y']);
    });

    test('non-string steps/tools are filtered out', () {
      const raw = '{"arrival":{"steps":["ok",5,null],"tools":["t",true]}}';
      final restored = decodeRoutineScripts(raw);
      expect(restored[RoutineKind.arrival]!.steps, ['ok']);
      expect(restored[RoutineKind.arrival]!.tools, ['t']);
    });
  });
}
