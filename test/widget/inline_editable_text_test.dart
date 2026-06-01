import 'package:differentworld/shared/widgets/inline_editable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behavioural contract for the formless-CRUD atom. The dim overlay runs
/// a Ticker while editing, so these tests drive frames with explicit
/// `pump(duration)` calls and always commit (which tears the ticker
/// down) before the test ends — `pumpAndSettle` would spin on the
/// vsync-driven ticker forever.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      );

  // Tap the read affordance, then pump the build frame + the post-frame
  // focus/IME callback so we land in a focused TextField.
  Future<void> enterEdit(WidgetTester tester, Finder readText) async {
    await tester.tap(readText);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
  }

  Future<void> commitDone(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(); // runs the deferred overlay-remove + dispose
  }

  group('InlineEditableText', () {
    testWidgets('editable:false → plain text, no affordance, tap is inert',
        (tester) async {
      await tester.pumpWidget(host(InlineEditableText(
        value: 'Outdoor Play',
        editable: false,
        onCommit: (_) async {},
      )));

      expect(find.text('Outdoor Play'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      await tester.tap(find.text('Outdoor Play'));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tap → in-place TextField that holds focus', (tester) async {
      await tester.pumpWidget(host(InlineEditableText(
        value: 'Outdoor Play',
        onCommit: (_) async {},
      )));

      await enterEdit(tester, find.text('Outdoor Play'));

      expect(find.byType(TextField), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue);

      await commitDone(tester); // tear down the dim ticker
    });

    testWidgets('done commits the trimmed text exactly once', (tester) async {
      final commits = <String>[];
      await tester.pumpWidget(host(InlineEditableText(
        value: '',
        placeholder: 'Name this block',
        onCommit: (t) async => commits.add(t),
      )));

      await enterEdit(tester, find.text('Name this block'));
      await tester.enterText(find.byType(TextField), '  Swim  ');
      await commitDone(tester);

      expect(commits, ['Swim']);
    });

    testWidgets('clearable:false → emptying a named field is a no-op',
        (tester) async {
      final commits = <String>[];
      await tester.pumpWidget(host(InlineEditableText(
        value: 'Outdoor Play',
        clearable: false,
        onCommit: (t) async => commits.add(t),
      )));

      await enterEdit(tester, find.text('Outdoor Play'));
      await tester.enterText(find.byType(TextField), '');
      await commitDone(tester);

      expect(commits, isEmpty); // the wipe was swallowed
      expect(find.text('Outdoor Play'), findsOneWidget); // name retained
    });

    testWidgets('clearable:true (default) → clear-to-empty still commits',
        (tester) async {
      final commits = <String>[];
      await tester.pumpWidget(host(InlineEditableText(
        value: 'a note',
        onCommit: (t) async => commits.add(t),
      )));

      await enterEdit(tester, find.text('a note'));
      await tester.enterText(find.byType(TextField), '');
      await commitDone(tester);

      expect(commits, ['']); // delete-the-note is preserved for Notes
    });

    testWidgets('committing unchanged text does not fire onCommit',
        (tester) async {
      final commits = <String>[];
      await tester.pumpWidget(host(InlineEditableText(
        value: 'Outdoor Play',
        onCommit: (t) async => commits.add(t),
      )));

      await enterEdit(tester, find.text('Outdoor Play'));
      await commitDone(tester); // no edit between enter and commit

      expect(commits, isEmpty);
    });
  });
}
