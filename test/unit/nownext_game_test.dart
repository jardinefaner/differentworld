// NowNextGame — the schedule board presentable (docs/VISION.md #18).
// Data-driven (blocks seeded from the schedule); Back/Next walks the day.

import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_runner.dart';
import 'package:differentworld/features/games/games/nownext_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const def = NowNextGame();

  Map<String, dynamic> st({int i = 0}) => {
    'blocks': const [
      ['Snack', '3:00 PM', 'break'],
      ['Outside', '3:30 PM', 'on_site'],
      ['Art', '4:00 PM', 'on_site'],
    ],
    'i': i,
  };

  group('NowNextGame.reduce', () {
    test('next advances but clamps at the last block', () {
      expect(def.reduce(st(), GameIntent.next, const {})['i'], 1);
      expect(def.reduce(st(i: 2), GameIntent.next, const {})['i'], 2);
    });

    test('back steps back but clamps at the first; reset returns to 0', () {
      expect(def.reduce(st(i: 1), GameIntent.back, const {})['i'], 0);
      expect(def.reduce(st(), GameIntent.back, const {})['i'], 0);
      expect(def.reduce(st(i: 2), GameIntent.reset, const {})['i'], 0);
    });

    test('current + upNext track the index', () {
      final s = def.decode(st(i: 1));
      expect(s.current?.title, 'Outside');
      expect(s.upNext?.title, 'Art');
      expect(def.decode(st(i: 2)).upNext, isNull);
    });
  });

  testWidgets('shows NOW + NEXT and advances through the day', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: GameRunner(
            def: NowNextGame(),
            seed: {
              'blocks': [
                ['Snack', '3:00 PM', 'break'],
                ['Outside', '3:30 PM', 'on_site'],
                ['Art', '4:00 PM', 'on_site'],
              ],
              'i': 0,
            },
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Now'), findsOneWidget);
    expect(find.text('Snack'), findsOneWidget);
    expect(find.text('Outside'), findsOneWidget); // the NEXT banner
    expect(find.text('Art'), findsNothing);
    expect(find.text('1 of 3'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Art'), findsOneWidget); // Art is now NEXT
    expect(find.text('2 of 3'), findsOneWidget);
  });
}
