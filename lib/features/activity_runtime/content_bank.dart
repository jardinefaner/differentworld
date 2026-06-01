/// The content bank (docs/CONTENT_BANK.md) — activity content made once
/// and reused, served behind a source-agnostic interface.
///
/// This is the LOCAL implementation: curated seed lists in Dart with
/// in-session seen-tracking. The DB-backed [ContentSource]
/// (`content_items` + brokered-AI refill + crowd-grow) drops in behind the
/// same interface later, so activities never change.
library;

/// One banked item — a SEMANTIC_GRAPH noun. [fingerprint] is the de-dupe
/// key; [payload] is the shape the activity reads.
class ContentItem {
  const ContentItem({
    required this.kind,
    required this.fingerprint,
    required this.payload,
  });

  final String kind;
  final String fingerprint;
  final Map<String, Object?> payload;
}

/// Content kinds. Add a constant when a new activity needs banked content.
abstract class ContentKind {
  static const thisOrThat = 'this_or_that';
  static const category = 'category';
}

/// Source-agnostic content access. Activities depend on THIS, not on where
/// the content lives. The DB bank implements the same shape.
abstract class ContentSource {
  /// The next unseen item of [kind], or null when the bank is dry.
  ContentItem? next(String kind);

  /// Up to [n] unseen items of [kind] (marks them seen), for a round.
  List<ContentItem> take(String kind, int n);

  /// Unseen items remaining for [kind].
  int remaining(String kind);
}

/// A local, in-session bank over curated seed lists. Serves unseen items,
/// de-duped by fingerprint; "seen" is tracked in memory for the session.
class LocalContentBank implements ContentSource {
  LocalContentBank(List<ContentItem> items) {
    for (final item in items) {
      // De-dupe at load — uniqueness is the bank's job, never the
      // activity's (docs/CONTENT_BANK.md §4).
      if (_seenFingerprints.add('${item.kind}/${item.fingerprint}')) {
        (_byKind[item.kind] ??= <ContentItem>[]).add(item);
      }
    }
  }

  /// Seed the bank with the curated content shipped in the app.
  factory LocalContentBank.seeded() => LocalContentBank([
    ..._thisOrThatSeed,
    ..._categorySeed,
  ]);

  final Map<String, List<ContentItem>> _byKind = {};
  final Set<String> _seenFingerprints = <String>{};
  final Set<String> _served = <String>{};

  String _key(ContentItem i) => '${i.kind}/${i.fingerprint}';

  @override
  ContentItem? next(String kind) {
    for (final item in _byKind[kind] ?? const <ContentItem>[]) {
      if (_served.add(_key(item))) return item;
    }
    return null;
  }

  @override
  List<ContentItem> take(String kind, int n) {
    final out = <ContentItem>[];
    for (var i = 0; i < n; i++) {
      final item = next(kind);
      if (item == null) break;
      out.add(item);
    }
    return out;
  }

  @override
  int remaining(String kind) => (_byKind[kind] ?? const <ContentItem>[])
      .where((i) => !_served.contains(_key(i)))
      .length;

  /// Forget what's been served this session (e.g. play again).
  void reset() => _served.clear();
}

// ── Curated seeds ──────────────────────────────────────────────────────
// Kid-safe by construction (the curated tier, docs/CONTENT_BANK.md §1).
// Fingerprints are stable so the DB bank can de-dupe against these.

ContentItem _torOf(String a, String b) => ContentItem(
  kind: ContentKind.thisOrThat,
  fingerprint: '${a.toLowerCase()}|${b.toLowerCase()}',
  payload: {'a': a, 'b': b},
);

final List<ContentItem> _thisOrThatSeed = <ContentItem>[
  _torOf('Pizza', 'Tacos'),
  _torOf('Summer', 'Winter'),
  _torOf('Dogs', 'Cats'),
  _torOf('Be able to fly', 'Be invisible'),
  _torOf('Mountains', 'The ocean'),
  _torOf('Draw it', 'Build it'),
  _torOf('Morning', 'Night'),
  _torOf('Chocolate', 'Vanilla'),
  _torOf('Read the book', 'Watch the movie'),
  _torOf('Explore space', 'Explore the deep sea'),
  _torOf('Always sunny', 'Always snowy'),
  _torOf('Super speed', 'Super strength'),
  _torOf('Sweet', 'Salty'),
  _torOf('A big party', 'A quiet hangout'),
  _torOf('Time travel to the past', 'Time travel to the future'),
  _torOf('Sing', 'Dance'),
];

ContentItem _categoryOf(String label) => ContentItem(
  kind: ContentKind.category,
  fingerprint: label.toLowerCase(),
  payload: {'label': label},
);

final List<ContentItem> _categorySeed = <ContentItem>[
  _categoryOf('an animal'),
  _categoryOf('a food'),
  _categoryOf('a place in the world'),
  _categoryOf('something you find at school'),
  _categoryOf('a color'),
  _categoryOf('a sport or game'),
  _categoryOf('something in the kitchen'),
  _categoryOf('a job people do'),
  _categoryOf('something that flies'),
  _categoryOf('a thing in nature'),
  _categoryOf('something you wear'),
  _categoryOf('a kind of music'),
];
