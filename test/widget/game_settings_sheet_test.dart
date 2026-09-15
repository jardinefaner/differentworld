// The settings SHEET — the half of a knob a teacher actually touches.
//
// `game_settings_test.dart` proves the values reach the round: turn the round
// length down and the round gets shorter. It proves nothing about the control,
// and `ChoiceSetting` shipped with a brand-new one. A single-pick row and a
// multi-pick row look nearly the same and behave nothing alike, so a teacher
// who taps "Gentle" expecting "Usual" to switch off, and finds both lit, has
// been told something false about the round.

import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/game_settings_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Open the sheet and hand back whatever it returns on Apply.
Future<Map<String, Object?>?> _open(
  WidgetTester tester,
  List<GameSetting> settings,
) async {
  Map<String, Object?>? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showGameSettings(
                  context,
                  settings: settings,
                  initial: defaultSettingValues(settings),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return result;
}

Future<Map<String, Object?>?> _apply(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Start a new round'));
  await tester.pumpAndSettle();
  return null;
}

void main() {
  testWidgets('a level is drawn as a row of chips, one of them on', (
    tester,
  ) async {
    await _open(tester, [difficulty()]);

    for (final label in ['Gentle', 'Usual', 'Tricky']) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
    final lit = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((c) => c.selected)
        .length;
    expect(lit, 1, reason: 'a single pick must show exactly one chip on');
  });

  testWidgets('picking a level turns the other two OFF', (tester) async {
    // The whole reason ChoiceSetting is not a MultiSetting.
    await _open(tester, [difficulty()]);
    await tester.tap(find.text('Gentle'));
    await tester.pumpAndSettle();

    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(
      chips.where((c) => c.selected).length,
      1,
      reason: 'two levels lit at once — the round can only have one',
    );
  });

  testWidgets('the chosen level comes back out on Apply', (tester) async {
    // The control and the value have to be the same thing. A chip that lights
    // up and returns the default is the worst of both.
    Map<String, Object?>? out;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  out = await showGameSettings(
                    context,
                    settings: [difficulty()],
                    initial: defaultSettingValues([difficulty()]),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tricky'));
    await tester.pumpAndSettle();
    await _apply(tester);

    expect(out, isNotNull, reason: 'the sheet returned nothing');
    expect(
      difficultyFrom(out!),
      GameDifficulty.tricky,
      reason: 'the sheet lit Tricky and handed back ${out![difficultyId]}',
    );
  });

  testWidgets('re-tapping the chosen level keeps it — a round has a level', (
    tester,
  ) async {
    await _open(tester, [difficulty()]);
    await tester.tap(find.text('Usual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usual'));
    await tester.pumpAndSettle();

    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip));
    expect(
      chips.where((c) => c.selected).length,
      1,
      reason: 'tapping the lit chip turned it off — there is no "no level"',
    );
  });
}
