import 'dart:convert';

import 'package:flutter/material.dart';

/// The starter mission catalog + the model helpers (docs/MISSIONS.md). The
/// templates are seeded into a program's editable `missions` table with one
/// tap; each program then tailors its own manual.

/// What proof a mission asks for when it's done.
enum MissionEvidenceKind {
  photo('photo', 'Photo', Icons.photo_camera_outlined),
  count('count', 'A count', Icons.tag),
  note('note', 'A note', Icons.edit_note_outlined),
  check('check', 'Just a check', Icons.check_circle_outline)
  ;

  const MissionEvidenceKind(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;

  static MissionEvidenceKind fromKey(String? key) {
    for (final k in MissionEvidenceKind.values) {
      if (k.key == key) return k;
    }
    return MissionEvidenceKind.check;
  }
}

/// Decode the `actions` JSON-array column into a list of step strings.
/// Tolerant: null / blank / malformed → empty list.
List<String> decodeMissionActions(String? json) {
  if (json == null || json.trim().isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    if (decoded is List) {
      return decoded
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
  } on FormatException catch (_) {
    // Malformed JSON → empty. Never throw from a render path.
  }
  return const [];
}

/// Encode a list of step strings into the `actions` column (drops blanks).
String encodeMissionActions(List<String> actions) => jsonEncode(
  actions.map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
);

/// A shipped starter mission — added (editable) to a program's catalog.
class MissionTemplate {
  const MissionTemplate({
    required this.icon,
    required this.name,
    required this.tagline,
    required this.why,
    required this.builds,
    required this.rules,
    required this.actions,
    required this.evidence,
    this.minAge,
    this.maxAge,
  });

  final String icon;
  final String name;
  final String tagline;
  final String why;
  final String builds;
  final String rules;
  final List<String> actions;
  final MissionEvidenceKind evidence;
  final int? minAge;
  final int? maxAge;
}

/// The shipped starter set (docs/MISSIONS.md). Order here is the seed sort.
const missionTemplates = <MissionTemplate>[
  MissionTemplate(
    icon: '🏀',
    name: 'Equipment Manager',
    tagline: 'Gear in, gear out, all accounted for',
    why: 'Our gear lasts when someone looks after it.',
    builds: 'responsibility',
    rules:
        'Balls live in the bin by the gym door. Jump ropes coiled on the '
        'hook. Count before and after. Anything broken — tell a counselor, '
        "don't throw it out.",
    actions: [
      'Hand the gear out fairly',
      'Count it back in',
      'Wipe, coil, and stack it',
      'Put it where the manual says',
      'Report anything missing or broken',
    ],
    evidence: MissionEvidenceKind.photo,
    minAge: 7,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '🍎',
    name: 'Snack Helper',
    tagline: 'Everyone eats when snack runs smoothly',
    why: 'A calm snack means everyone gets a turn.',
    builds: 'service',
    rules:
        'Wash hands first. One each until everyone has had a turn. Check the '
        'allergy list — that table is separate. Wipe the tables after. '
        'Leftovers back in the labeled bin.',
    actions: [
      'Wash your hands',
      'Set out napkins and cups',
      'Hand out one each',
      'Wipe the tables',
      'Pack leftovers and count them',
    ],
    evidence: MissionEvidenceKind.photo,
    minAge: 4,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '🧹',
    name: 'Cleanup Crew',
    tagline: 'Everything back in its home',
    why: 'A clear room is ready for the next great thing.',
    builds: 'teamwork',
    rules:
        'Chairs up, floor clear, everything in its home. A five-minute sweep '
        'before we move on.',
    actions: [
      'Put the chairs up',
      'Pick up the floor',
      'Return items to their shelves',
      'Scan for anything out of place',
      'High-five the crew',
    ],
    evidence: MissionEvidenceKind.photo,
    minAge: 4,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '📦',
    name: 'Supply Keeper',
    tagline: 'Restock it, flag what is low',
    why: 'We never run out when someone is watching the shelves.',
    builds: 'diligence',
    rules:
        'Restock the art cart from the cabinet. If something is running low, '
        'flag it in Supplies. Caps on the markers, lids on the glue.',
    actions: [
      'Check the cart',
      'Restock from the cabinet',
      'Cap and lid everything',
      'Flag low items in Supplies',
      'Tidy the cabinet',
    ],
    evidence: MissionEvidenceKind.photo,
    minAge: 8,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '🚸',
    name: 'Line Leader',
    tagline: 'Walking feet, count the heads',
    why: 'We stay together when someone leads the way.',
    builds: 'leadership',
    rules:
        'Lead from the front. Walking feet. Wait at every door. Count heads.',
    actions: [
      'Line everyone up',
      'Count heads',
      'Lead with walking feet',
      'Wait at every door',
      'Recount when we arrive',
    ],
    evidence: MissionEvidenceKind.count,
    minAge: 4,
    maxAge: 8,
  ),
  MissionTemplate(
    icon: '👋',
    name: 'Greeter',
    tagline: 'Welcome everyone by name',
    why: 'A friendly hello makes this place feel like ours.',
    builds: 'kindness',
    rules:
        'Welcome each arrival by name. Show new kids the cubbies, the '
        'bathroom, and the rules. Introduce them to a buddy.',
    actions: [
      'Greet each arrival by name',
      'Show a new kid around',
      'Help with cubbies',
      'Introduce them to a buddy',
    ],
    evidence: MissionEvidenceKind.note,
    minAge: 5,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '📚',
    name: 'Library Keeper',
    tagline: 'Books home, spines out',
    why: 'The next reader finds the book they want.',
    builds: 'order',
    rules:
        'Books go spine-out, by section. Bookmarks out. Torn pages to the '
        'repair bin.',
    actions: [
      'Gather the stray books',
      'Shelve them by section',
      'Turn every spine out',
      'Set aside any that are damaged',
    ],
    evidence: MissionEvidenceKind.photo,
    minAge: 5,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '💡',
    name: 'Lights & Doors',
    tagline: 'Last one out checks',
    why: 'Small habits take care of the whole building.',
    builds: 'responsibility',
    rules:
        'Lights off when we leave a room. Doors held for the line, closed '
        'after. The last one out does the final check.',
    actions: [
      'Lights off when leaving',
      'Hold or close the door',
      'Do a final scan of the room',
    ],
    evidence: MissionEvidenceKind.check,
    minAge: 4,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '♻️',
    name: 'Recycle Captain',
    tagline: 'Paper blue, cans green',
    why: 'We take care of more than just our room.',
    builds: 'stewardship',
    rules: 'Paper in blue, cans in green, trash is trash. Rinse if sticky.',
    actions: [
      'Check the bins',
      'Sort anything in the wrong one',
      'Take the full bins out',
      'Put in a fresh bag',
    ],
    evidence: MissionEvidenceKind.photo,
    minAge: 6,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '🌱',
    name: 'Plant & Pet Caretaker',
    tagline: 'Water, feed, fresh water',
    why: 'Living things count on us, every day.',
    builds: 'care',
    rules:
        'Finger-test the soil before watering. A measured scoop for the pet. '
        'Fresh water every day.',
    actions: [
      'Check the soil with a finger',
      'Water only if it is dry',
      'Feed the measured amount',
      'Give fresh water',
      'Note how they are doing',
    ],
    evidence: MissionEvidenceKind.photo,
    minAge: 5,
    maxAge: 12,
  ),
  MissionTemplate(
    icon: '🤝',
    name: 'Peace Buddy',
    tagline: 'Help friends use their words',
    why: 'Everyone deserves a calm way through a hard moment.',
    builds: 'empathy',
    rules:
        'Help friends use their words. Offer the calm corner. Get a counselor '
        'for the big problems.',
    actions: [
      'Notice someone who seems upset',
      'Ask "are you okay?"',
      'Offer to listen or the calm corner',
      'Get an adult for big problems',
    ],
    evidence: MissionEvidenceKind.note,
    minAge: 7,
    maxAge: 12,
  ),
];
