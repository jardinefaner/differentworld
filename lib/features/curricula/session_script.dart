// Runnable / castable SESSION SCRIPTS — the full minute-by-minute beat
// sequence behind a [PhotoSession] summary (see photo_curriculum.dart).
//
// Where photo_curriculum.dart holds the at-a-glance summary of a session
// (big idea, game name, materials), THIS is the host-facing presenter
// content: every beat the staffer walks through, in order, with "every
// word to say" preserved VERBATIM. It is the content foundation for a
// beat-by-beat session presenter (built next) — a runnable/castable
// flow where each beat is its own slide with its own timer.
//
// Plain Dart const data on purpose: no freezed, no codegen. The scripts
// are editorial — readable at zero latency, offline-forever, shipped in
// the binary like the curriculum it sits behind. A per-space override
// table can layer on later; the slug stays so tooling can reference a
// specific session.
//
// Editorial voice MATTERS. The say-lines are the script the host reads
// aloud — they are intentional and must NOT be paraphrased in code.

/// What kind of beat this is — drives the slide's icon / accent and lets
/// the presenter group the arc (hook → reveal → rules → games → cooldown
/// → drawing → vocab → closing). One [BeatKind] per timed section.
enum BeatKind {
  /// Before the kids arrive — room setup, materials to stage.
  prep,

  /// The opening attention-grab that lands the session's premise.
  hook,

  /// The premise made concrete (the camera reveal).
  reveal,

  /// Teaching the mechanic the games run on (the camera's rules).
  rules,

  /// A shooting / play beat that hands off to per-child photo turns.
  game,

  /// The quiet contrast beat after high energy (the special object).
  cooldown,

  /// A verbal pair exercise — communication, not camera-turns.
  partner,

  /// An imagination beat — pointing where a described photo would be.
  frame,

  /// Drawing the day's best shots into the journal.
  drawing,

  /// Adding the session's earned words to the vocabulary wall.
  vocab,

  /// The closing circle — the wrap, the homework, the call-and-response.
  closing,

  /// The doorway send-off as each kid leaves.
  doorway,

  /// After the kids leave — the host's own reset for next time.
  after,
}

/// The kind of a single line in a beat's full script.
enum ScriptLineKind {
  /// A line the host says aloud — VERBATIM, never paraphrased.
  say,

  /// A stage direction (what the host does / what happens in the room).
  cue,

  /// A shout-back / answer the kids give.
  response,

  /// An aside or announcer-style call — context, not a spoken line.
  note,
}

/// One ordered line within [SessionBeat.script]. Constructed via the
/// named constructors so the [kind] is unambiguous at the call site:
/// `ScriptLine.say('…')`, `ScriptLine.cue('…')`, etc.
class ScriptLine {
  const ScriptLine.say(this.text) : kind = ScriptLineKind.say;
  const ScriptLine.cue(this.text) : kind = ScriptLineKind.cue;
  const ScriptLine.response(this.text) : kind = ScriptLineKind.response;
  const ScriptLine.note(this.text) : kind = ScriptLineKind.note;

  final ScriptLineKind kind;
  final String text;
}

/// A game beat's shooting payload — the "Start shooting" handoff to the
/// per-child photo turns. Only the camera-turns games carry one (the
/// Speed Round, the three Outdoor Hunt rounds). Verbal beats (Partner
/// Frame) and imagination beats (Frame Game) leave [SessionBeat.game]
/// null.
class BeatGame {
  const BeatGame({
    required this.name,
    this.rules = const [],
    this.minutes,
    this.prompt,
  });

  /// The game's display name (e.g. "The Speed Round").
  final String name;

  /// The shooting rules, in order — pulled verbatim from the script.
  final List<String> rules;

  /// Shooting minutes for the timer on this beat, when the script names
  /// one.
  final int? minutes;

  /// The shooting mission — the one-line instruction the kids carry into
  /// the turn (e.g. "Ten interesting things, two minutes").
  final String? prompt;
}

/// One beat of a session — a single presenter slide with its own timer.
/// [keyLines] is the CALM view (the 1-3 most essential say-lines shown
/// by default); [script] is the FULL beat, tap-to-expand.
class SessionBeat {
  const SessionBeat({
    required this.time,
    required this.kind,
    required this.title,
    this.startMinute,
    this.durationMinutes,
    this.keyLines = const [],
    this.script = const [],
    this.callResponse,
    this.game,
    this.vocabCards = const [],
  });

  /// The header label — a clock range like `"0:03–0:06"`, or `"prep"` /
  /// `"after"` for the untimed bookend beats.
  final String time;

  final BeatKind kind;
  final String title;

  /// Minutes into the session this beat starts (null for prep / after).
  final int? startMinute;

  /// How long this beat runs, when the header gives a range.
  final int? durationMinutes;

  /// The CALM view — the 1-3 most important say-lines a host needs at a
  /// glance, verbatim (trimmed). A subset of [script].
  final List<String> keyLines;

  /// The FULL beat as an ordered list (say / cue / response / note in
  /// script order) — what tap-to-expand reveals.
  final List<ScriptLine> script;

  /// The headline shout for this beat where there's a clear one, e.g.
  /// `"PHOTOGRAPHERS"`. Null when the beat has no single call.
  final String? callResponse;

  /// For shooting beats: the "Start shooting" handoff. Null for verbal /
  /// imagination beats.
  final BeatGame? game;

  /// For the vocabulary beat: the word cards to tape up (definitions
  /// live in the beat's [script] lines).
  final List<String> vocabCards;
}

/// The full beat sequence behind one PhotoSession summary (see
/// photo_curriculum.dart). [slug] matches the summary's slug so tooling
/// can join the two.
class SessionScript {
  const SessionScript({
    required this.slug,
    required this.sessionNumber,
    required this.title,
    required this.beats,
  });

  final String slug;
  final int sessionNumber;
  final String title;
  final List<SessionBeat> beats;
}
