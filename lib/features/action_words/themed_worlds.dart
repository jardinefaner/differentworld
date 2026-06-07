import 'package:differentworld/features/action_words/senses.dart';
import 'package:flutter/foundation.dart';

/// A **themed world** — one of the program's standing "Different Worlds."
/// The umbrella is *Different World*; each room is a world the kids step
/// into and help build. NOT a weekly rotation — these map to the 5 rooms
/// the program already has (docs/WORLD.md). The daily 3-verb Action Words
/// world (everyday) nests inside the bigger themed world (the room).
@immutable
class ThemedWorld {
  const ThemedWorld({
    required this.id,
    required this.emoji,
    required this.name,
    required this.tagline,
    required this.senses,
  });

  final String id;
  final String emoji;

  /// "World of Books".
  final String name;

  /// A one-line invitation into the world.
  final String tagline;

  /// How the room enters this world through the senses ("become it").
  final List<SenseBeat> senses;
}

/// The program's worlds — the "Different World" anthology. A starter set
/// keyed to the rooms a summer program runs; programs rename / extend.
const List<ThemedWorld> kThemedWorlds = [
  ThemedWorld(
    id: 'books',
    emoji: '📚',
    name: 'World of Books',
    tagline: 'Open a book and step inside the story.',
    senses: [
      SenseBeat(Sense.look, 'Open the book — what do you see inside?'),
      SenseBeat(Sense.sound, 'Read it out loud — be the storyteller'),
    ],
  ),
  ThemedWorld(
    id: 'movies',
    emoji: '🎬',
    name: 'World of Movies',
    tagline: 'Lights, camera — make the scene and act it out.',
    senses: [
      SenseBeat(Sense.move, 'Action! — act the scene with your whole body'),
      SenseBeat(Sense.sound, 'Say the line, make the movie sounds'),
    ],
  ),
  ThemedWorld(
    id: 'songs',
    emoji: '🎵',
    name: 'World of Songs',
    tagline: 'Find the beat, sing it, move to it.',
    senses: [
      SenseBeat(Sense.sound, 'Sing it out — hear the beat'),
      SenseBeat(Sense.move, 'Dance the way the song feels'),
    ],
  ),
  ThemedWorld(
    id: 'dreams',
    emoji: '🌙',
    name: 'World of Dreams',
    tagline: 'Close your eyes — anything can happen here.',
    senses: [
      SenseBeat(Sense.look, 'Eyes closed — picture it in your mind'),
      SenseBeat(Sense.move, 'Float slow and soft, like a dream'),
    ],
  ),
  ThemedWorld(
    id: 'space',
    emoji: '🚀',
    name: 'World of Space',
    tagline: 'Out past the sky, among the stars.',
    senses: [
      SenseBeat(Sense.look, 'Find the brightest star and reach for it'),
      SenseBeat(Sense.move, 'Float weightless — slow and quiet'),
    ],
  ),
  ThemedWorld(
    id: 'time',
    emoji: '⏳',
    name: 'World of Time',
    tagline: 'Speed it up, slow it down, freeze the moment.',
    senses: [
      SenseBeat(Sense.move, 'Move fast… then slow… then freeze'),
      SenseBeat(Sense.look, 'Watch the clock — tick, tick, tick'),
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

/// A facet of a world — one of the things a "different world" is made of.
/// "If they were to create a different world, what's in this?" — the
/// people, the culture, the (pretend) map, the tools, the dreams. These
/// are the DIMENSIONS every world shares; the room fills in the content
/// for its own world (the buildable canvas is a follow-up slice).
@immutable
class WorldFacet {
  const WorldFacet({
    required this.id,
    required this.emoji,
    required this.name,
    required this.prompt,
  });

  final String id;
  final String emoji;
  final String name;

  /// The question that invites the room to build this facet.
  final String prompt;
}

/// What's in a world. The anatomy the kids + teachers build together.
const List<WorldFacet> kWorldFacets = [
  WorldFacet(
    id: 'people',
    emoji: '👥',
    name: 'People',
    prompt: 'Who lives in this world? Who do you meet here?',
  ),
  WorldFacet(
    id: 'culture',
    emoji: '🎭',
    name: 'Culture',
    prompt: 'How do they do things here — their ways, words, celebrations?',
  ),
  WorldFacet(
    id: 'map',
    emoji: '🗺️',
    name: 'Map',
    // SECURITY: the world map is INVENTED geography only — never a
    // child's real home / location. Make-believe places, full stop.
    prompt: 'The places of this world — all make-believe, none real.',
  ),
  WorldFacet(
    id: 'tools',
    emoji: '🛠️',
    name: 'Tools',
    prompt: 'What do you use here? What helps you on the way?',
  ),
  WorldFacet(
    id: 'dreams',
    emoji: '✨',
    name: 'Dreams',
    prompt: 'What does this world hope for? What’s the big dream here?',
  ),
];
