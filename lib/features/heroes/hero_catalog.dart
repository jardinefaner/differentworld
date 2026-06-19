import 'dart:convert';

import 'package:flutter/foundation.dart';

/// The **Heroes** activity catalog + models (docs/VISION.md 2026-06-19).
///
/// A kid assembles an alter-ego from curated pick-lists — an animal, a skin
/// (variant look), super powers, a `[Name] of [From]` title, and a drawing
/// they name. The result is a **Hero card**: a keepsake, not a quiz, that
/// accumulates into the Book + showcase.
///
/// Everything here is pure data — no I/O. The pick-lists are kid-mode
/// no-typing (the only typed field is the hero's name). Picks are
/// **denormalized** into the saved entry's `details` (label + emoji snapshot,
/// not just an id) so a Hero card stays stable even if this catalog later
/// changes — a keepsake should never silently relabel itself.

/// One option in a pick-list — an animal, a skin, or a power.
@immutable
class HeroPick {
  const HeroPick(this.id, this.label, this.emoji);

  factory HeroPick.fromJson(Map<String, dynamic> j) => HeroPick(
    (j['id'] as String?) ?? '',
    (j['label'] as String?) ?? '',
    (j['emoji'] as String?) ?? '',
  );

  final String id;
  final String label;
  final String emoji;

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'emoji': emoji};
}

/// The animals a hero can be.
const List<HeroPick> heroAnimals = <HeroPick>[
  HeroPick('fox', 'Fox', '🦊'),
  HeroPick('owl', 'Owl', '🦉'),
  HeroPick('wolf', 'Wolf', '🐺'),
  HeroPick('bear', 'Bear', '🐻'),
  HeroPick('rabbit', 'Rabbit', '🐰'),
  HeroPick('turtle', 'Turtle', '🐢'),
  HeroPick('cat', 'Cat', '🐱'),
  HeroPick('dog', 'Dog', '🐶'),
  HeroPick('lion', 'Lion', '🦁'),
  HeroPick('dolphin', 'Dolphin', '🐬'),
  HeroPick('dragon', 'Dragon', '🐲'),
  HeroPick('tiger', 'Tiger', '🐯'),
];

/// The skin (look) of the animal.
const List<HeroPick> heroSkins = <HeroPick>[
  HeroPick('midnight', 'Midnight', '🌙'),
  HeroPick('golden', 'Golden', '✨'),
  HeroPick('frost', 'Frost', '❄️'),
  HeroPick('ember', 'Ember', '🔥'),
  HeroPick('shadow', 'Shadow', '🌑'),
  HeroPick('storm', 'Storm', '⛈️'),
  HeroPick('forest', 'Forest', '🌲'),
  HeroPick('rainbow', 'Rainbow', '🌈'),
];

/// The super powers a hero can have (pick a few).
const List<HeroPick> heroPowers = <HeroPick>[
  HeroPick('invisible', 'Turns invisible', '🫥'),
  HeroPick('speed', 'Super speed', '💨'),
  HeroPick('fly', 'Can fly', '🪽'),
  HeroPick('strength', 'Super strength', '💪'),
  HeroPick('healing', 'Healing touch', '💚'),
  HeroPick('animals', 'Talks to animals', '🐾'),
  HeroPick('shrink', 'Shrinks tiny', '🐜'),
  HeroPick('glow', 'Glows in the dark', '🌟'),
  HeroPick('hearing', 'Super hearing', '👂'),
  HeroPick('shield', 'Makes force fields', '🛡️'),
  HeroPick('water', 'Breathes underwater', '🫧'),
  HeroPick('mind', 'Reads minds', '🧠'),
];

/// The `[Name] of [From]` places — picked, no typing.
const List<String> heroOrigins = <String>[
  'the Willow Woods',
  'the Tall Mountains',
  'the Deep Sea',
  'the Stars',
  'the Old Library',
  'the Hidden Cave',
  'the Sunny Meadow',
  'the Frozen North',
  'the Great City',
  'the Secret Garden',
];

/// How many powers a hero may hold — keeps the card readable + the choice
/// meaningful (you can't pick everything).
const int heroMaxPowers = 3;

/// An assembled hero the creator hands to `EntryActions.recordHero`. The
/// drawing (a photo of what they drew) is threaded separately through the
/// photo pipeline, not held here.
@immutable
class HeroDraft {
  const HeroDraft({
    required this.animal,
    required this.skin,
    required this.powers,
    required this.name,
    required this.from,
    this.drawingName,
  });

  final HeroPick animal;
  final HeroPick skin;
  final List<HeroPick> powers;
  final String name;
  final String from;
  final String? drawingName;

  /// Serialized into the entry's `details` cell — the denormalized snapshot.
  String toDetailsJson() => jsonEncode(<String, dynamic>{
    'animal': animal.toJson(),
    'skin': skin.toJson(),
    'powers': powers.map((p) => p.toJson()).toList(),
    'name': name,
    'from': from,
    'drawing_name': ?drawingName,
  });
}

/// A saved hero, parsed back out of an entry's `details` for the Hero card.
/// Tolerant of partial/legacy rows — every field has a sane fallback so a
/// half-built or future-shaped row never throws on render.
@immutable
class HeroCardData {
  const HeroCardData({
    required this.animal,
    required this.skin,
    required this.powers,
    required this.name,
    required this.from,
    required this.drawingName,
  });

  final HeroPick? animal;
  final HeroPick? skin;
  final List<HeroPick> powers;
  final String name;
  final String from;
  final String? drawingName;

  /// The `[Name] of [From]` title, gracefully degrading if a piece is missing.
  String get title {
    final n = name.trim();
    final f = from.trim();
    if (n.isEmpty) return f.isEmpty ? 'My hero' : 'A hero of $f';
    return f.isEmpty ? n : '$n of $f';
  }

  /// "Midnight Fox" — the skin + animal subtitle.
  String get speciesLabel {
    final parts = <String>[
      if (skin != null && skin!.label.isNotEmpty) skin!.label,
      if (animal != null && animal!.label.isNotEmpty) animal!.label,
    ];
    return parts.join(' ');
  }

  static HeroCardData? tryParse(String detailsJson) {
    try {
      final j = jsonDecode(detailsJson);
      if (j is! Map<String, dynamic>) return null;
      final animalJson = j['animal'];
      final skinJson = j['skin'];
      final powersJson = j['powers'];
      return HeroCardData(
        animal: animalJson is Map<String, dynamic>
            ? HeroPick.fromJson(animalJson)
            : null,
        skin: skinJson is Map<String, dynamic>
            ? HeroPick.fromJson(skinJson)
            : null,
        powers: powersJson is List
            ? powersJson
                  .whereType<Map<String, dynamic>>()
                  .map(HeroPick.fromJson)
                  .toList()
            : const <HeroPick>[],
        name: (j['name'] as String?) ?? '',
        from: (j['from'] as String?) ?? '',
        drawingName: (j['drawing_name'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['drawing_name'] as String).trim(),
      );
    } on Object {
      return null;
    }
  }
}
