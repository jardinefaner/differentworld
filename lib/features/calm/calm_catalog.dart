import 'package:flutter/foundation.dart';

/// **What to do instead** (docs/VISION.md 2026-06-19) — the room's calm,
/// co-held reference: what to do in every feeling (mad / bored / anxious / sad),
/// plus the agreements that are common ground. *"not noise, just a list."*
///
/// Pure, read-only data — no writes, no schema. A reference the room returns to,
/// host-presented or printed, offline-first. Kid-safe (4–12), in-proximity
/// (nothing needs a phone or a screen).

/// A feeling + the small things to try when it shows up.
@immutable
class CalmFeeling {
  const CalmFeeling(this.id, this.label, this.emoji, this.actions);

  final String id;
  final String label;
  final String emoji;
  final List<String> actions;
}

/// The feelings, each with a few calm, doable, in-the-room actions.
const List<CalmFeeling> calmFeelings = <CalmFeeling>[
  CalmFeeling('mad', 'When I’m mad', '🌋', [
    'Take 5 big breaths',
    'Squeeze your hands, then let go',
    'Find a quiet corner',
    'Ask a grown-up for a break',
    'Stomp it out, then sit down',
  ]),
  CalmFeeling('anxious', 'When I’m worried', '🌧️', [
    'Name 5 things you can see',
    'Take slow belly breaths',
    'Hold something soft',
    'Tell a grown-up how you feel',
    'Picture your calm place',
  ]),
  CalmFeeling('sad', 'When I’m sad', '💧', [
    'It’s okay to feel sad',
    'Find a friend to sit with',
    'Draw how you feel',
    'Ask for a hug',
    'Take a quiet moment',
  ]),
  CalmFeeling('bored', 'When I’m bored', '🥱', [
    'Start a small mission',
    'Draw what you see',
    'Help someone with their task',
    'Make up a story in your head',
    'Count the blue things in the room',
  ]),
  CalmFeeling('wiggly', 'When I can’t sit still', '⚡', [
    'Do 10 big jumps',
    'Push the wall hard for 10 seconds',
    'Take one lap of the room',
    'Shake it all out',
    'Stretch up tall, then fold down',
  ]),
];

/// The room's agreements — common ground, co-held. Kept short and positive.
const List<String> roomAgreements = <String>[
  'We use kind words',
  'We take turns',
  'We listen when someone speaks',
  'We ask before we borrow',
  'We help when someone is stuck',
  'We clean up together',
];
