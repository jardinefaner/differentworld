// The "frame instead of a picture" proof (docs/SEMANTIC_GRAPH.md).
//
// These assert the STRUCTURE of the UI — where each noun is, in what
// state, with what actions — read from the render tree, no screenshot.
// This is the pattern that replaces font-fragile golden PNGs with stable
// structural facts.

import 'package:differentworld/shared/semantics/noun_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NounScope / captureFrame', () {
    testWidgets('captures each noun with rect, id, state, and actions',
        (tester) async {
      final reg = NounRegistry();
      await tester.pumpWidget(
        MaterialApp(
          home: NounRegistryScope(
            registry: reg,
            child: const Scaffold(
              body: Column(
                children: [
                  NounScope(
                    noun: 'ScheduleBlock',
                    id: 'b1',
                    actions: ['tap', 'edit'],
                    state: {'editing': false},
                    child: SizedBox(width: 100, height: 40),
                  ),
                  NounScope(
                    noun: 'ScheduleBlock',
                    id: 'b2',
                    state: {'editing': true},
                    child: SizedBox(width: 100, height: 60),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final frame = reg.capture();

      expect(frame.whereNoun('ScheduleBlock'), hasLength(2));

      final b1 = frame.byId('ScheduleBlock', 'b1')!;
      expect(b1.actions, ['tap', 'edit']);
      expect(b1.state['editing'], isFalse);
      expect(b1.rect.size, const Size(100, 40));

      final b2 = frame.byId('ScheduleBlock', 'b2')!;
      expect(b2.state['editing'], isTrue);
      expect(b2.rect.size, const Size(100, 60));

      // Reading order: b1 sits above b2, so it sorts first.
      expect(b1.rect.top, lessThan(b2.rect.top));
      expect(frame.nodes.first.id, 'b1');

      // PII-safe: the serialized frame is shape, not content.
      expect(reg.capture().toJson()['nodes'], isA<List<Object?>>());
    });

    testWidgets('a noun that unmounts leaves the frame', (tester) async {
      final reg = NounRegistry();

      Widget build({required bool showSecond}) => MaterialApp(
            home: NounRegistryScope(
              registry: reg,
              child: Scaffold(
                body: Column(
                  children: [
                    const NounScope(
                      noun: 'ScheduleBlock',
                      id: 'b1',
                      child: SizedBox(width: 80, height: 20),
                    ),
                    if (showSecond)
                      const NounScope(
                        noun: 'ScheduleBlock',
                        id: 'b2',
                        child: SizedBox(width: 80, height: 20),
                      ),
                  ],
                ),
              ),
            ),
          );

      await tester.pumpWidget(build(showSecond: true));
      expect(reg.count, 2);

      await tester.pumpWidget(build(showSecond: false));
      await tester.pump();

      expect(reg.count, 1);
      expect(reg.capture().byId('ScheduleBlock', 'b2'), isNull);
      expect(reg.capture().byId('ScheduleBlock', 'b1'), isNotNull);
    });

    testWidgets('state updates flow into the next frame (no re-register)',
        (tester) async {
      final reg = NounRegistry();

      Widget build({required bool editing}) => MaterialApp(
            home: NounRegistryScope(
              registry: reg,
              child: Scaffold(
                body: NounScope(
                  noun: 'ScheduleBlock',
                  id: 'b1',
                  state: {'editing': editing},
                  child: const SizedBox(width: 50, height: 50),
                ),
              ),
            ),
          );

      await tester.pumpWidget(build(editing: false));
      expect(reg.capture().byId('ScheduleBlock', 'b1')!.state['editing'],
          isFalse);

      await tester.pumpWidget(build(editing: true));
      expect(reg.count, 1, reason: 'updating state must not re-register');
      expect(reg.capture().byId('ScheduleBlock', 'b1')!.state['editing'],
          isTrue);
    });

    testWidgets('no registry ancestor → NounScope is an inert passthrough',
        (tester) async {
      // Degrades gracefully: the app works with no frame system mounted.
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NounScope(
              noun: 'ScheduleBlock',
              id: 'b1',
              child: Text('hello'),
            ),
          ),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
    });
  });
}
