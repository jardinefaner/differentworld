// The Routines voice layer (docs/VISION.md 2026-06-19) turns a staff block
// name into a kid-facing sublabel + icon. Pure mapping — pin the matching
// rules so a rename or reorder can't silently regress the voice.

import 'package:differentworld/features/routines/routine_voice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PE gets the body-workout voice + a running icon', () {
    expect(RoutineVoice.sublabelFor('PE'), 'the workout for your body');
    expect(RoutineVoice.iconFor('PE'), Icons.directions_run_outlined);
  });

  test('brain breaks get the brain-workout voice (the named example)', () {
    expect(
      RoutineVoice.sublabelFor('Brain breaks'),
      'the workout for your brain',
    );
    expect(
      RoutineVoice.sublabelFor('Brain Break Time'),
      'the workout for your brain',
    );
    expect(RoutineVoice.iconFor('Brain breaks'), Icons.bolt_outlined);
  });

  test('snack + lunch fuel up', () {
    expect(RoutineVoice.sublabelFor('Snack time'), 'fuel up');
    expect(RoutineVoice.sublabelFor('Lunch'), 'fuel up');
  });

  test('showcase practice reads as "for the big show"', () {
    expect(
      RoutineVoice.sublabelFor('Showcase practice'),
      'for the big show',
    );
  });

  test(
    'short tokens match whole words only — "pe" must not hit other words',
    () {
      // 'pe' is a substring of "spelling"/"open" but not a whole word, so the
      // PE rule must not fire.
      expect(RoutineVoice.sublabelFor('Spelling bee'), isNull);
      // "Open play" should resolve via the whole word "play", not PE.
      expect(RoutineVoice.sublabelFor('Open play'), 'play together');
    },
  );

  test('unknown blocks degrade — no sublabel, neutral clock icon', () {
    expect(RoutineVoice.sublabelFor('Bus loading'), isNull);
    expect(RoutineVoice.iconFor('Bus loading'), Icons.schedule_outlined);
  });
}
