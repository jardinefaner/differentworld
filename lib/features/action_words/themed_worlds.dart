import 'package:flutter/foundation.dart';

/// A facet of a world — one of the ten things a "different world" is made
/// of. "If they were to create a different world, what's in this?" These are
/// the shared DIMENSIONS; the authored content per world lives in the
/// curriculum catalog (lib/features/action_words/curriculum.dart, keyed by
/// facet id). The order here is the order they're shown.
@immutable
class WorldFacet {
  const WorldFacet({
    required this.id,
    required this.emoji,
    required this.name,
  });

  final String id;
  final String emoji;
  final String name;
}

/// The ten facets, in display order — matches the curriculum's section list.
/// NOTE: the Map facet is always INVENTED geography (make-believe places),
/// never a child's real location.
const List<WorldFacet> kWorldFacets = [
  WorldFacet(id: 'people', emoji: '👤', name: 'The People'),
  WorldFacet(id: 'culture', emoji: '🎭', name: 'The Culture'),
  WorldFacet(id: 'map', emoji: '🗺️', name: 'The Map'),
  WorldFacet(id: 'tools', emoji: '🔧', name: 'The Tools'),
  WorldFacet(id: 'language', emoji: '💬', name: 'The Language'),
  WorldFacet(id: 'food', emoji: '🍽️', name: 'The Food'),
  WorldFacet(id: 'music', emoji: '🎵', name: 'The Music'),
  WorldFacet(id: 'rules', emoji: '📜', name: 'The Rules'),
  WorldFacet(id: 'problems', emoji: '⚠️', name: 'The Problems'),
  WorldFacet(id: 'dreams', emoji: '💫', name: 'The Dreams'),
];
