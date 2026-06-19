import 'package:flutter/material.dart';

/// The **Routines voice layer** (docs/VISION.md 2026-06-19).
///
/// A schedule block staff named "PE" or "Brain breaks" reads to a 6-year-old
/// as nothing. This pure mapping gives each block a kid-facing **sublabel**
/// ("the workout for your body") and a friendly **icon**, so the room's day
/// becomes a rhythm they can predict and belong to — without touching the
/// staff schedule or adding a column. First matching rule wins; an unknown
/// block degrades gracefully (no sublabel, a neutral icon).
///
/// This is a render-time voice, not stored data — so it restyles every
/// existing block for free and stays easy to tune.
class RoutineVoice {
  const RoutineVoice._();

  /// The warm kid-facing line under a block's title, or null if none fits.
  static String? sublabelFor(String label) => _match(label)?.sublabel;

  /// A friendly icon for the block, or a neutral clock if nothing fits.
  static IconData iconFor(String label) =>
      _match(label)?.icon ?? Icons.schedule_outlined;

  static _Rule? _match(String label) {
    final lower = label.toLowerCase();
    final words = lower
        .split(RegExp('[^a-z]+'))
        .where((w) => w.isNotEmpty)
        .toSet();
    for (final rule in _rules) {
      for (final kw in rule.keywords) {
        // Phrases match as substrings; single tokens match whole words only
        // (so "pe" matches "PE" but not "open").
        final hit = kw.contains(' ') ? lower.contains(kw) : words.contains(kw);
        if (hit) return rule;
      }
    }
    return null;
  }
}

class _Rule {
  const _Rule(this.keywords, this.sublabel, this.icon);

  final List<String> keywords;
  final String sublabel;
  final IconData icon;
}

// Order matters — more specific rules first (e.g. "brain break" before the
// generic "break"). Keywords are lowercase; single tokens match whole words.
const List<_Rule> _rules = <_Rule>[
  _Rule(
    ['brain break', 'brain breaks'],
    'the workout for your brain',
    Icons.bolt_outlined,
  ),
  _Rule(
    ['pe', 'gym', 'exercise', 'fitness', 'phys'],
    'the workout for your body',
    Icons.directions_run_outlined,
  ),
  _Rule(
    ['sing', 'song', 'music', 'choir'],
    'warm up your voice',
    Icons.music_note_outlined,
  ),
  _Rule(
    ['showcase', 'rehearsal', 'rehearse', 'practice', 'recital'],
    'for the big show',
    Icons.star_outline,
  ),
  _Rule(
    ['snack', 'lunch', 'breakfast', 'meal', 'eat', 'dinner'],
    'fuel up',
    Icons.restaurant_outlined,
  ),
  _Rule(
    ['read', 'reading', 'story', 'book', 'library'],
    'travel somewhere in a book',
    Icons.menu_book_outlined,
  ),
  _Rule(
    ['nap', 'rest', 'quiet', 'calm', 'breathe', 'mindful'],
    'let your battery recharge',
    Icons.bedtime_outlined,
  ),
  _Rule(
    ['art', 'draw', 'drawing', 'craft', 'crafts', 'paint', 'painting'],
    'make something new',
    Icons.palette_outlined,
  ),
  _Rule(
    ['outside', 'outdoor', 'playground', 'recess', 'park', 'field'],
    'fresh air and big moves',
    Icons.park_outlined,
  ),
  _Rule(
    ['clean', 'tidy', 'pack up', 'cleanup', 'pack'],
    'reset the room together',
    Icons.cleaning_services_outlined,
  ),
  _Rule(
    ['circle', 'meeting', 'morning', 'gather', 'welcome', 'greeting'],
    'everyone together',
    Icons.groups_outlined,
  ),
  _Rule(
    ['math', 'maths', 'number', 'numbers'],
    'puzzle your brain',
    Icons.calculate_outlined,
  ),
  _Rule(
    ['science', 'experiment', 'discover', 'stem'],
    'find out how things work',
    Icons.science_outlined,
  ),
  _Rule(
    ['water', 'swim', 'swimming', 'pool', 'splash'],
    'splash time',
    Icons.pool_outlined,
  ),
  _Rule(
    ['game', 'games', 'play'],
    'play together',
    Icons.sports_esports_outlined,
  ),
];
