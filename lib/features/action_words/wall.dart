import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:flutter/foundation.dart';

/// What a Wall note is about. Every world has its Problems and its Dreams
/// ("sticky notes on the wall", docs/WORLD.md); the Feelings world adds the
/// "something nobody knows you feel" prompt.
enum WallNoteType {
  problem('⚠️', 'Problem', 'What is this world working on?'),
  dream('✨', 'Dream', 'What is the big dream here?'),
  feeling('💛', 'Feeling', 'Something nobody knows you feel'),
  free('📝', 'Note', 'A note for the wall')
  ;

  const WallNoteType(this.emoji, this.label, this.prompt);
  final String emoji;
  final String label;
  final String prompt;

  static WallNoteType fromName(String? name) {
    for (final t in WallNoteType.values) {
      if (t.name == name) return t;
    }
    return WallNoteType.free;
  }
}

/// A parsed Wall note — anonymous by design (we never surface who wrote it).
@immutable
class WallNote {
  const WallNote({
    required this.id,
    required this.text,
    required this.type,
    required this.worldId,
    required this.recordedAt,
  });

  factory WallNote.fromEntry(Entry e) {
    Map<String, dynamic> details;
    try {
      final d = jsonDecode(e.details);
      details = d is Map<String, dynamic> ? d : const {};
    } on FormatException {
      details = const {};
    }
    return WallNote(
      id: e.id,
      text: e.body ?? '',
      type: WallNoteType.fromName(details['note_type'] as String?),
      worldId: (details['world_id'] as String?) ?? '',
      recordedAt: e.recordedAt,
    );
  }

  final String id;
  final String text;
  final WallNoteType type;
  final String worldId;
  final String recordedAt;
}

/// Parse + filter a list of `wall_note` entries to one world's notes,
/// newest first.
List<WallNote> wallNotesForWorld(List<Entry> entries, String worldId) {
  final out = <WallNote>[];
  for (final e in entries) {
    final note = WallNote.fromEntry(e);
    if (note.worldId == worldId && note.text.isNotEmpty) out.add(note);
  }
  return out;
}
