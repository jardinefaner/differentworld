import 'package:flutter/foundation.dart';

/// A teachable SKILL — "the teacher teaches one skill a day" (the brief).
/// The tools a kid needs to be successful: sign language, cursive, shapes,
/// breathing… Each carries a one-line "how to teach it in 2 minutes" so the
/// daily promise isn't hollow (the Red Team's Blocker 3). Programs extend.
@immutable
class TeachSkill {
  const TeachSkill({
    required this.id,
    required this.emoji,
    required this.name,
    required this.how,
  });

  final String id;
  final String emoji;
  final String name;

  /// A 2-minute teaching prompt a teacher can run cold.
  final String how;
}

const List<TeachSkill> kSkills = [
  TeachSkill(
    id: 'sign',
    emoji: '🤟',
    name: 'Sign language',
    how: 'Teach one sign — the sign for this week’s world. Sign it together '
        'three times.',
  ),
  TeachSkill(
    id: 'cursive',
    emoji: '✍️',
    name: 'Cursive',
    how: 'One cursive letter. Trace it big in the air first, then on paper.',
  ),
  TeachSkill(
    id: 'shapes',
    emoji: '🔷',
    name: 'Drawing shapes',
    how: 'Draw a circle, a square, a triangle — slow, narrating each stroke.',
  ),
  TeachSkill(
    id: 'breathing',
    emoji: '🌬️',
    name: 'Breathing',
    how: 'In for 4, hold for 4, out for 4. Hand on the belly to feel it.',
  ),
  TeachSkill(
    id: 'scissors',
    emoji: '✂️',
    name: 'Scissors',
    how: 'Thumbs up, cut along a line. Open wide, close all the way.',
  ),
  TeachSkill(
    id: 'laces',
    emoji: '👟',
    name: 'Tying laces',
    how: 'Bunny ears, cross them, one through the loop, pull.',
  ),
  TeachSkill(
    id: 'counting',
    emoji: '🔢',
    name: 'Counting',
    how: 'Count to 20 together, then count by 2s as far as you can.',
  ),
  TeachSkill(
    id: 'letters',
    emoji: '🔤',
    name: 'Letter of the day',
    how: 'One letter — its sound, and a word from this week’s world that '
        'starts with it.',
  ),
  TeachSkill(
    id: 'name',
    emoji: '🪪',
    name: 'Writing your name',
    how: 'Write your name, one letter at a time. First letter capital.',
  ),
  TeachSkill(
    id: 'listening',
    emoji: '👂',
    name: 'Listening',
    how: 'Close eyes, 30 seconds. Hold up a finger for each sound you hear.',
  ),
];

TeachSkill? skillById(String? id) {
  if (id == null) return null;
  for (final s in kSkills) {
    if (s.id == id) return s;
  }
  return null;
}

/// A SUGGESTED skill for [now] — rotates one per day so there's always one
/// up, deterministically (the teacher can still pick a different one). Pure.
TeachSkill skillForDay(DateTime now) {
  final day = DateTime(now.year, now.month, now.day)
      .difference(DateTime(2026))
      .inDays;
  return kSkills[day.abs() % kSkills.length];
}
