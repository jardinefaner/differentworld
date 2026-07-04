/// Group Discussions (docs/VISION.md dream #6) — a host-present discussion
/// activity. The teacher picks a TOPIC + an AGE BAND; the room talks through
/// curated, kid-safe starters. No typing, no right answer, teacher-paced.
///
/// Plain-Dart catalog for now (the same pattern as roles.dart). The same
/// shape moves behind the content bank — kind `discussion`, tagged by topic
/// + band — when it goes DB-backed + brokered-AI-grown
/// (docs/CONTENT_BANK.md). Activities won't change, only where the prompts
/// come from.
library;

/// Afterschool age bands — the 4–12 segment is the primary product context
/// (CLAUDE.md). A prompt can suit more than one band.
enum DiscussionBand {
  early('4–6', 'Ages 4–6'),
  middle('7–9', 'Ages 7–9'),
  older('10–12', 'Ages 10–12')
  ;

  const DiscussionBand(this.short, this.label);

  /// Compact label for a chip ("7–9").
  final String short;

  /// Full label for the segmented control ("Ages 7–9").
  final String label;
}

/// A topic — the "shelf" in the library.
class DiscussionTopic {
  const DiscussionTopic(this.id, this.label, this.emoji);

  final String id;
  final String label;
  final String emoji;
}

const discussionTopics = <DiscussionTopic>[
  DiscussionTopic('friendship', 'Friendship', '🤝'),
  DiscussionTopic('feelings', 'Feelings', '💛'),
  DiscussionTopic('imagination', 'Imagination', '🚀'),
  DiscussionTopic('fairness', 'Fairness', '⚖️'),
  DiscussionTopic('world', 'Our World', '🌍'),
  DiscussionTopic('kindness', 'Kindness', '🌟'),
  DiscussionTopic('dreams', 'Dreams & Goals', '✨'),
  DiscussionTopic('courage', 'Being Brave', '🦁'),
];

/// One discussion starter. [bands] is the set of age bands it suits;
/// [deeper] is an optional follow-up the host can reveal to keep the talk
/// going when the room has more to say.
class Discussion {
  const Discussion({
    required this.topicId,
    required this.prompt,
    required this.bands,
    this.deeper,
  });

  final String topicId;
  final String prompt;
  final Set<DiscussionBand> bands;
  final String? deeper;

  /// De-dupe key (the content-bank fingerprint convention).
  String get fingerprint => prompt.toLowerCase();
}

// Band-set shorthands so the library reads cleanly.
const Set<DiscussionBand> _e = {DiscussionBand.early};
const Set<DiscussionBand> _em = {DiscussionBand.early, DiscussionBand.middle};
const Set<DiscussionBand> _mo = {DiscussionBand.middle, DiscussionBand.older};
const Set<DiscussionBand> _o = {DiscussionBand.older};
const Set<DiscussionBand> _all = {
  DiscussionBand.early,
  DiscussionBand.middle,
  DiscussionBand.older,
};

/// The shipped starter library — kid-safe by construction, open-ended (no
/// right answer), graded across the three afterschool bands.
const discussionLibrary = <Discussion>[
  // ── Friendship ──────────────────────────────────────────────────────
  Discussion(
    topicId: 'friendship',
    prompt: 'What makes someone a good friend?',
    bands: _all,
    deeper: 'How do you show a friend you like playing with them?',
  ),
  Discussion(
    topicId: 'friendship',
    prompt: "What's a fun thing to do with a friend?",
    bands: _em,
  ),
  Discussion(
    topicId: 'friendship',
    prompt: 'Two friends want to play different games. What do you do?',
    bands: _mo,
    deeper: 'Is there a way everyone gets a turn?',
  ),
  Discussion(
    topicId: 'friendship',
    prompt: 'Can you be friends with someone very different from you? How?',
    bands: _o,
  ),
  // ── Feelings ────────────────────────────────────────────────────────
  Discussion(
    topicId: 'feelings',
    prompt: 'What makes you feel happy?',
    bands: _all,
    deeper: 'Can you show us your happy face?',
  ),
  Discussion(
    topicId: 'feelings',
    prompt: 'What helps you calm down when you feel upset?',
    bands: _em,
  ),
  Discussion(
    topicId: 'feelings',
    prompt: 'Where in your body do you feel it when you get nervous?',
    bands: _mo,
    deeper: 'What helps that feeling get smaller?',
  ),
  Discussion(
    topicId: 'feelings',
    prompt: "What's the difference between feeling mad and feeling hurt?",
    bands: _o,
  ),
  // ── Imagination ─────────────────────────────────────────────────────
  Discussion(
    topicId: 'imagination',
    prompt: 'If you could fly, where would you go first?',
    bands: _all,
  ),
  Discussion(
    topicId: 'imagination',
    prompt: 'If your shoes could talk, what would they say?',
    bands: _em,
  ),
  Discussion(
    topicId: 'imagination',
    prompt: 'Invent a brand-new holiday. What do we celebrate?',
    bands: _mo,
    deeper: 'What food would we eat on your holiday?',
  ),
  Discussion(
    topicId: 'imagination',
    prompt: 'If you ran this place for a day, what would you change first?',
    bands: _o,
  ),
  // ── Fairness ────────────────────────────────────────────────────────
  Discussion(
    topicId: 'fairness',
    prompt: 'Is it fair if one person gets all the blocks? Why?',
    bands: _e,
  ),
  Discussion(
    topicId: 'fairness',
    prompt: 'Someone cuts the line. What should happen?',
    bands: _mo,
    deeper: "What's a fair way to decide who goes first?",
  ),
  Discussion(
    topicId: 'fairness',
    prompt: 'Is being fair the same as everyone getting the exact same thing?',
    bands: _o,
  ),
  Discussion(
    topicId: 'fairness',
    prompt:
        'Have you seen something that felt unfair? What did you wish happened?',
    bands: _mo,
  ),
  // ── Our World ───────────────────────────────────────────────────────
  Discussion(
    topicId: 'world',
    prompt: "What's your favorite thing in nature?",
    bands: _all,
  ),
  Discussion(
    topicId: 'world',
    prompt: "What's one way we can take care of the Earth?",
    bands: _em,
  ),
  Discussion(
    topicId: 'world',
    prompt: 'If you could visit anywhere in the world, where — and why?',
    bands: _mo,
    deeper: 'What would you want to learn while you were there?',
  ),
  Discussion(
    topicId: 'world',
    prompt: "What's one problem in the world you'd want to help fix?",
    bands: _o,
  ),
  // ── Kindness ────────────────────────────────────────────────────────
  Discussion(
    topicId: 'kindness',
    prompt: "What's a kind thing someone did for you?",
    bands: _all,
  ),
  Discussion(
    topicId: 'kindness',
    prompt: 'How can you make a new kid feel welcome?',
    bands: _em,
    deeper: 'What could you say to them first?',
  ),
  Discussion(
    topicId: 'kindness',
    prompt: "What's a small kindness that doesn't cost anything?",
    bands: _mo,
  ),
  Discussion(
    topicId: 'kindness',
    prompt: 'Is it ever hard to be kind? When?',
    bands: _o,
  ),
  // ── Dreams & Goals ──────────────────────────────────────────────────
  Discussion(
    topicId: 'dreams',
    prompt: 'What do you want to be when you grow up?',
    bands: _all,
  ),
  Discussion(
    topicId: 'dreams',
    prompt: "What's something you'd like to get better at?",
    bands: _mo,
    deeper: "What's one small step you could take this week?",
  ),
  Discussion(
    topicId: 'dreams',
    prompt: "What's a big dream you have — even if it sounds impossible?",
    bands: _mo,
  ),
  Discussion(
    topicId: 'dreams',
    prompt: 'Who is someone you look up to, and why?',
    bands: _o,
  ),
  // ── Being Brave ─────────────────────────────────────────────────────
  Discussion(
    topicId: 'courage',
    prompt: "What's something brave you did?",
    bands: _all,
  ),
  Discussion(
    topicId: 'courage',
    prompt: 'What helps you feel brave when you feel scared?',
    bands: _em,
  ),
  Discussion(
    topicId: 'courage',
    prompt: 'Is it brave to say sorry? Why?',
    bands: _mo,
    deeper: 'When is saying sorry the hardest?',
  ),
  Discussion(
    topicId: 'courage',
    prompt:
        "What's the difference between being brave and not being scared at all?",
    bands: _o,
  ),
];

/// Prompts for [band], optionally filtered to one [topicId] (null = any
/// topic). Order is the library order; the runner shuffles + caps a session.
List<Discussion> discussionsFor(DiscussionBand band, {String? topicId}) =>
    discussionLibrary
        .where((d) => d.bands.contains(band))
        .where((d) => topicId == null || d.topicId == topicId)
        .toList();

/// Topics that have at least one prompt for [band] (so the picker never
/// offers an empty shelf).
List<DiscussionTopic> topicsFor(DiscussionBand band) => discussionTopics
    .where(
      (t) => discussionLibrary.any(
        (d) => d.topicId == t.id && d.bands.contains(band),
      ),
    )
    .toList();

/// Lookup a topic by id (for the header + chip labels).
DiscussionTopic? topicById(String id) {
  for (final t in discussionTopics) {
    if (t.id == id) return t;
  }
  return null;
}
