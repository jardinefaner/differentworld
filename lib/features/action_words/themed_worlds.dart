import 'package:differentworld/features/action_words/senses.dart';
import 'package:flutter/foundation.dart';

/// A **themed world** — the bigger "different world" a room steps into for
/// a couple of weeks (the brief's themed rooms). Where the daily 3-verb
/// world is *everyday*, the themed world is the *weekly* sensory immersion
/// the daily world nests inside (docs/ACTION_WORDS.md). Programs own +
/// extend this list; the daily Action Words mechanic is theme-agnostic.
@immutable
class ThemedWorld {
  const ThemedWorld({
    required this.id,
    required this.emoji,
    required this.name,
    required this.room,
    required this.blurb,
    required this.senses,
  });

  final String id;
  final String emoji;
  final String name;

  /// The physical room this world lives in ("Safari Room").
  final String room;

  /// A one-line invitation into the world.
  final String blurb;

  /// How the room enters this world through the senses.
  final List<SenseBeat> senses;
}

/// The starter set (the brief's sequence). The teacher sets which one the
/// room is in this week; replace / extend freely.
const List<ThemedWorld> kThemedWorlds = [
  ThemedWorld(
    id: 'all_about_me',
    emoji: '🪞',
    name: 'All About Me',
    room: 'Home Room',
    blurb: 'Who am I? Getting to know each other.',
    senses: [
      SenseBeat(Sense.look, 'Look in the mirror — what do you see?'),
      SenseBeat(Sense.touch, 'Press a handprint that’s only yours'),
    ],
  ),
  ThemedWorld(
    id: 'wildlife',
    emoji: '🦁',
    name: 'Wildlife',
    room: 'Safari Room',
    blurb: 'Animals and the wild places they live.',
    senses: [
      SenseBeat(Sense.sound, 'Call like an animal — loud, then soft'),
      SenseBeat(Sense.move, 'Move the way it moves — stalk, hop, soar'),
    ],
  ),
  ThemedWorld(
    id: 'travel',
    emoji: '✈️',
    name: 'Travel',
    room: 'Travel Room',
    blurb: 'Places far away and how we get there.',
    senses: [
      SenseBeat(Sense.look, 'Find a place on the map — point to it'),
      SenseBeat(Sense.move, 'Fly, drive, or sail your way there'),
    ],
  ),
  ThemedWorld(
    id: 'water_world',
    emoji: '🌊',
    name: 'Water World',
    room: 'Underwater Room',
    blurb: 'Under the sea — what lives down deep.',
    senses: [
      SenseBeat(Sense.touch, 'Feel the water, cool and smooth'),
      SenseBeat(Sense.sound, 'Listen for waves and whale song'),
    ],
  ),
  ThemedWorld(
    id: 'icons',
    emoji: '🏙️',
    name: 'Icons',
    room: 'Urban Room',
    blurb: 'The city, its buildings, and its heroes.',
    senses: [
      SenseBeat(Sense.look, 'Look up — how tall can a building be?'),
      SenseBeat(Sense.sound, 'Make the sounds of a busy street'),
    ],
  ),
  ThemedWorld(
    id: 'space',
    emoji: '🚀',
    name: 'Space',
    room: 'Space Room',
    blurb: 'The stars, the planets, and the dark between.',
    senses: [
      SenseBeat(Sense.look, 'Find the brightest star and reach for it'),
      SenseBeat(Sense.move, 'Float weightless, slow and quiet'),
    ],
  ),
];

ThemedWorld? themedWorldById(String? id) {
  if (id == null) return null;
  for (final w in kThemedWorlds) {
    if (w.id == id) return w;
  }
  return null;
}
