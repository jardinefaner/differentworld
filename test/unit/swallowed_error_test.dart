// `.value ?? const []` renders a FAILED read as an EMPTY result. The two
// are not the same thing and the difference matters most exactly where the
// app is most confident:
//
//   - class memory said "nothing kept yet" about a history the teacher had
//     spent weeks building
//   - the room page showed an empty roster to someone standing in a full
//     room, with "Add a child" underneath
//
// This test does not exercise widgets — it guards the PATTERN, by checking
// that the screens which watch async data also mention an error branch.
// Crude, deliberately: a screen can pass this and still be wrong, but a
// screen that fails it is definitely wrong, and the failure mode it catches
// is silent by nature.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Screens that watch async providers and must distinguish the states.
  const guarded = <String>[
    'lib/features/groups/room_setup_screen.dart',
    'lib/features/class_memory/class_memory_screen.dart',
    'lib/features/launch/launch_screen.dart',
    // Added 2026-09-03 by the platform-rubric second pass: it read
    // `groupsProvider` as `.value ?? const []`, so a failed room load silently
    // removed the role-practice door from a child's own world.
    'lib/features/child_world/child_world_screen.dart',
  ];

  for (final path in guarded) {
    test('${path.split('/').last} distinguishes failed from empty', () {
      final src = File(path).readAsStringSync();
      final swallows = RegExp(r'\.value \?\?').allMatches(src).length;
      if (swallows == 0) return; // nothing async to get wrong

      expect(
        src.contains('hasError'),
        isTrue,
        reason:
            '$path uses `.value ??` $swallows time(s) but never checks '
            'hasError, so a failed read renders as an empty one. That is '
            'the app telling a confident lie about missing data.',
      );
    });
  }

  test('the check can actually fail', () {
    // A file that swallows and never checks would be caught.
    const bad = 'final x = ref.watch(p).value ?? const [];';
    expect(RegExp(r'\.value \?\?').hasMatch(bad), isTrue);
    expect(bad.contains('hasError'), isFalse);
  });
}
