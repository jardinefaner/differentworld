import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A short pre-activity video — the "spark" in Watch → Talk → Do. The video
/// is never the lesson; it's the invitation. [after] is the Talk-prompt +
/// the activity it ignites (docs/curriculum/ten_worlds_videos.md).
@immutable
class WorldVideo {
  const WorldVideo({
    required this.title,
    required this.minutes,
    required this.after,
  });

  factory WorldVideo.fromJson(Map<String, dynamic> j) => WorldVideo(
        title: (j['title'] as String?) ?? '',
        minutes: (j['minutes'] as num?)?.toInt() ?? 3,
        after: (j['after'] as String?) ?? '',
      );

  final String title;
  final int minutes;
  final String after;
}

/// One week of the "If You Built a World" curriculum — a themed world with
/// its ten facets, featured verbs, activities, and Watch → Do videos.
/// Loaded from the bundled JSON (offline-first); the docs are the source of
/// truth (docs/curriculum/).
@immutable
class CurriculumWorld {
  const CurriculumWorld({
    required this.week,
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.tagline,
    required this.question,
    required this.facets,
    required this.featuredVerbs,
    required this.verbsNote,
    required this.activities,
    required this.videos,
  });

  factory CurriculumWorld.fromJson(Map<String, dynamic> j) => CurriculumWorld(
        week: (j['week'] as num?)?.toInt() ?? 0,
        id: (j['id'] as String?) ?? '',
        name: (j['name'] as String?) ?? '',
        emoji: (j['emoji'] as String?) ?? '🌍',
        color: _parseHexColor(j['color'] as String?),
        tagline: (j['tagline'] as String?) ?? '',
        question: (j['question'] as String?) ?? '',
        facets: <String, String>{
          for (final e in (j['facets'] as Map? ?? const {}).entries)
            e.key.toString(): e.value.toString(),
        },
        featuredVerbs: <String>[
          for (final v in (j['featuredVerbs'] as List? ?? const []))
            v.toString(),
        ],
        verbsNote: (j['verbsNote'] as String?) ?? '',
        activities: <String>[
          for (final a in (j['activities'] as List? ?? const [])) a.toString(),
        ],
        videos: <WorldVideo>[
          for (final v in (j['videos'] as List? ?? const []))
            if (v is Map<String, dynamic>) WorldVideo.fromJson(v),
        ],
      );

  final int week;
  final String id;
  final String name;
  final String emoji;
  final Color color;
  final String tagline;
  final String question;

  /// Facet id (people / culture / map / tools / language / food / music /
  /// rules / problems / dreams) → the authored content for this world.
  final Map<String, String> facets;
  final List<String> featuredVerbs;
  final String verbsNote;
  final List<String> activities;
  final List<WorldVideo> videos;
}

Color _parseHexColor(String? hex) {
  if (hex == null) return const Color(0xFF888888);
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? const Color(0xFF888888) : Color(value);
}

/// The full 10-week curriculum, loaded once from the bundled JSON. Offline-
/// first: the asset ships in the app bundle, no network.
final curriculumWorldsProvider = FutureProvider<List<CurriculumWorld>>((
  ref,
) async {
  final raw = await rootBundle.loadString('assets/curriculum/ten_worlds.json');
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const [];
  final worlds = decoded['worlds'];
  if (worlds is! List) return const [];
  return [
    for (final w in worlds)
      if (w is Map<String, dynamic>) CurriculumWorld.fromJson(w),
  ]..sort((a, b) => a.week.compareTo(b.week));
});

/// The screen-time discipline for the Watch → Talk → Do video layer. Shown
/// to teachers so the spark stays a spark (docs/curriculum/ten_worlds_videos.md).
const List<String> kScreenTimeRules = [
  'One video per day. 3–5 minutes, never longer than 7.',
  'The video comes BEFORE the activity, never after. It’s the spark, not the reward.',
  'Lights off for nature & space videos — make it an event.',
  'Pause and ask “what did you notice?” before doing the activity.',
  'Never force a second viewing — that’s their choice at quiet time.',
];
