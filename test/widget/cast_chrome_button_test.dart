// The app-wide cast affordance renders as a tappable cast control (slice 1).
// AppShell gates it to staff + hides it in immersive/kid-mode; this pins the
// button itself.

import 'package:differentworld/features/live_session/cast_chrome_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a cast control with the "Cast to a screen" tooltip',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CastChromeButton())),
      ),
    );
    expect(find.byIcon(Icons.cast), findsOneWidget);
    expect(find.byTooltip('Cast to a screen'), findsOneWidget);
  });
}
