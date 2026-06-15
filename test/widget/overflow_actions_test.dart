import 'package:differentworld/shared/widgets/overflow_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hosts [OverflowActions] at a forced viewport width so the
/// phone-vs-wider inline budget is deterministic (FormFactor reads
/// MediaQuery.sizeOf). 360 dp == compact phone (budget 1).
Widget _host(Widget child, {Size size = const Size(360, 800)}) {
  return MaterialApp(
    home: Scaffold(
      body: MediaQuery(
        data: MediaQueryData(size: size),
        child: Align(alignment: Alignment.topRight, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('phone: two actions both render inline, no overflow menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        OverflowActions([
          EdgeAction(
            icon: Icons.add,
            label: 'New',
            isPrimary: true,
            onPressed: () {},
          ),
          EdgeAction(icon: Icons.edit, label: 'Edit', onPressed: () {}),
        ]),
      ),
    );

    // Two actions on a phone (budget 1): a one-item menu is pointless, so
    // both stay inline and no "⋯" appears.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });

  testWidgets('phone: secondaries collapse into the menu, primary stays '
      'inline and menu taps dispatch', (tester) async {
    var editFired = false;
    await tester.pumpWidget(
      _host(
        OverflowActions([
          EdgeAction(
            icon: Icons.add,
            label: 'New',
            isPrimary: true,
            onPressed: () {},
          ),
          EdgeAction(
            icon: Icons.edit,
            label: 'Edit',
            onPressed: () => editFired = true,
          ),
          EdgeAction(icon: Icons.delete, label: 'Delete', onPressed: () {}),
        ]),
      ),
    );

    // Primary verb is never collapsed.
    expect(find.byIcon(Icons.add), findsOneWidget);
    // Both secondaries moved behind the "⋯" — not inline.
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);

    // Open the menu → secondaries appear → selecting one fires its action.
    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(editFired, isTrue);
  });

  testWidgets('disabled actions are dropped, not shown', (tester) async {
    await tester.pumpWidget(
      _host(
        OverflowActions([
          EdgeAction(
            icon: Icons.add,
            label: 'New',
            isPrimary: true,
            onPressed: () {},
          ),
          // onPressed null → dropped entirely (hide-don't-disable).
          const EdgeAction(icon: Icons.edit, label: 'Edit', onPressed: null),
        ]),
      ),
    );

    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });

  testWidgets('wider viewport keeps more actions inline', (tester) async {
    await tester.pumpWidget(
      _host(
        size: const Size(1000, 800), // tablet: budget 3
        OverflowActions([
          EdgeAction(
            icon: Icons.add,
            label: 'New',
            isPrimary: true,
            onPressed: () {},
          ),
          EdgeAction(icon: Icons.edit, label: 'Edit', onPressed: () {}),
          EdgeAction(icon: Icons.share, label: 'Share', onPressed: () {}),
          EdgeAction(icon: Icons.print, label: 'Print', onPressed: () {}),
        ]),
      ),
    );

    // Four actions, budget 3 → 4 <= 3+1, all inline, no menu.
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.byIcon(Icons.print), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });
}
