import 'package:flutter_test/flutter_test.dart';

/// Tap through an activity's run-script to reach the activity itself.
///
/// These screens now OPEN on their briefing — the room is told what it is
/// about to do before it starts, which is the whole point of the feature for a
/// substitute. A test that asserts the first screen is the activity is
/// asserting the old first-run, so it walks the beats the way a person does.
Future<void> skipTheBriefing(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    final next = find.text('Next');
    final start = find.text('Start');
    if (start.evaluate().isNotEmpty) {
      await tester.tap(start);
      await tester.pumpAndSettle();
      return;
    }
    if (next.evaluate().isEmpty) return;
    await tester.tap(next);
    await tester.pumpAndSettle();
  }
}
