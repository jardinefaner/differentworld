import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The modal-free destructive contract: delete fires immediately, an Undo
/// snackbar appears, and tapping Undo runs the restore. No "are you sure?" wall.
void main() {
  testWidgets('deletes now, shows Undo, and Undo restores', (tester) async {
    var deleted = false;
    var undone = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => deleteWithUndo(
                context,
                label: 'Heavy Helper',
                onDelete: () async => deleted = true,
                onUndo: () async => undone = true,
              ),
              child: const Text('del'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('del'));
    await tester.pump(); // process the tap + the onDelete microtask
    await tester.pump(const Duration(milliseconds: 400)); // snackbar slides in

    expect(deleted, isTrue); // deleted up front — no confirm
    expect(find.text('Deleted Heavy Helper'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect(undone, isFalse);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(undone, isTrue); // Undo runs the restore

    await tester.pump(const Duration(seconds: 1)); // flush the dismiss
  });
}
