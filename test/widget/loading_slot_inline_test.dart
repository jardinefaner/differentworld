import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `LoadingSlot` renders a `ListView`, so putting one inside ANOTHER scroll
/// view hands it an unbounded height and Flutter throws "Vertical viewport was
/// given unbounded height" — a red error frame where the skeleton should be.
///
/// class_memory_screen.dart shipped exactly that: its loading branch sat in
/// the children of the screen's own ListView, so the one state the screen is
/// guaranteed to pass through on a cold launch was broken. It surfaced only
/// because the golden sweep renders that state.
///
/// There are ~94 LoadingSlot call sites, so this is a class, not an instance.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('inline inside a ListView lays out', (tester) async {
    await tester.pumpWidget(
      host(
        ListView(
          children: const [
            Text('header'),
            LoadingSlot(inline: true),
            Text('footer'),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('footer'), findsOneWidget);
  });

  testWidgets('inline cards inside a Column lay out', (tester) async {
    await tester.pumpWidget(
      host(
        const SingleChildScrollView(
          child: Column(
            children: [
              LoadingSlot(variant: LoadingVariant.cards, inline: true),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the check can actually fail — a non-inline slot in a list throws',
    (
      tester,
    ) async {
      // Pins the bug this exists to prevent. A test that cannot fail is worse
      // than none, because it is believed.
      await tester.pumpWidget(
        host(ListView(children: const [LoadingSlot()])),
      );
      expect(tester.takeException(), isNotNull);
    },
  );

  testWidgets('as a screen body it still fills and scrolls', (tester) async {
    await tester.pumpWidget(host(const LoadingSlot()));
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
  });
}
