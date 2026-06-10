import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wave 180 — `showGlassSheet` becomes a right-docked glass side panel at
/// desktop widths (>= Breakpoints.tablet = 1200) instead of a centered
/// dialog, while staying a Navigator route so `Navigator.pop(result)`
/// still resolves the returned Future. Below 1200 the existing
/// dialog/bottom-sheet behaviour is untouched.
///
/// These tests pin the three load-bearing contracts:
///   1. Desktop  -> right-docked panel (not a BottomSheet), content on
///      the right half of the window.
///   2. Phone    -> still a BottomSheet (byte-identical to before).
///   3. The picked value rides back through Navigator.pop on every width.
void main() {
  const contentKey = Key('panel-body');

  // Pumps a screen with one button that opens a glass sheet. The sheet
  // body has a tappable row that pops `picked`, so a test can both
  // locate the body and assert the return value.
  Widget harness({required void Function(String?) onResult}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final picked = await showGlassSheet<String>(
                  context: context,
                  builder: (_) => Column(
                    key: contentKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // A focusable so the Esc CallbackShortcut has a
                      // focused descendant to receive the key from.
                      const TextField(autofocus: true),
                      ListTile(
                        title: const Text('pick me'),
                        onTap: () => Navigator.of(context).pop('picked'),
                      ),
                    ],
                  ),
                );
                onResult(picked);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  void setWindow(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('desktop width docks a right-side panel, not a bottom sheet', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    await tester.pumpWidget(harness(onResult: (_) {}));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // It's the side-panel path: a general dialog, NOT a BottomSheet.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byKey(contentKey), findsOneWidget);

    // Body sits on the right half of the 1400px window (docked right,
    // ~460 wide => left edge well past centre).
    final left = tester.getTopLeft(find.byKey(contentKey)).dx;
    expect(left, greaterThan(700));
  });

  testWidgets('phone width still uses a bottom sheet', (tester) async {
    setWindow(tester, const Size(420, 900));
    await tester.pumpWidget(harness(onResult: (_) {}));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Unchanged phone behaviour: a real BottomSheet, full width.
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(contentKey), findsOneWidget);
    final left = tester.getTopLeft(find.byKey(contentKey)).dx;
    expect(left, lessThan(100));
  });

  testWidgets('side panel returns the picked value via Navigator.pop', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    String? captured;
    var called = false;
    await tester.pumpWidget(
      harness(
        onResult: (v) {
          captured = v;
          called = true;
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('pick me'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(captured, 'picked');
  });

  testWidgets('side panel dismisses on barrier tap (returns null)', (
    tester,
  ) async {
    setWindow(tester, const Size(1400, 900));
    String? captured = 'untouched';
    var called = false;
    await tester.pumpWidget(
      harness(
        onResult: (v) {
          captured = v;
          called = true;
        },
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(contentKey), findsOneWidget);

    // Tap the dimmed page on the left (outside the right-docked panel).
    await tester.tapAt(const Offset(120, 450));
    await tester.pumpAndSettle();

    expect(find.byKey(contentKey), findsNothing);
    expect(called, isTrue);
    expect(captured, isNull);
  });

  testWidgets('Escape closes the side panel', (tester) async {
    setWindow(tester, const Size(1400, 900));
    await tester.pumpWidget(harness(onResult: (_) {}));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(contentKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(contentKey), findsNothing);
  });
}
