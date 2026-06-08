import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/toolkit/toolkit_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// The printable toolkit's gesture guide iterates the 12 verbs — every one
/// must have a gesture, or the closing-game card prints a blank row.
void main() {
  test('every verb has a closing-game gesture', () {
    for (final v in kVerbs) {
      expect(
        kVerbGestures[v.id],
        isNotNull,
        reason: '${v.id} has no gesture',
      );
      expect(kVerbGestures[v.id]!.trim(), isNotEmpty);
    }
    // No stray gestures for verbs that don't exist.
    final verbIds = {for (final v in kVerbs) v.id};
    for (final id in kVerbGestures.keys) {
      expect(verbIds.contains(id), isTrue, reason: '$id is not a verb');
    }
  });
}
