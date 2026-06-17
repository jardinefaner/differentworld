import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:flutter/material.dart';

/// The unified game framework (docs/GAMES.md "The Game contract", VISION
/// #17). Every host-run game is one tiny contract — a state + a pure
/// reducer over the shared [GameIntent] vocabulary — and the framework
/// turns that into a thing that is controllable (tap + keyboard + a phone
/// remote), live (the reducer IS a LiveReducer), and familiar (one
/// scaffold), while each game keeps its own stage + vibe.
///
/// Primary model: **host-present, room-responds, teacher-tallies** — one
/// teacher device drives a projector; the room answers out loud / moves /
/// raises hands; the teacher taps the count. No per-kid devices required.
/// [GameIntent.submit] is the every-phone counterpart for when devices ARE
/// in the room (the Board, a word cloud), but [GameIntent.tally] is the
/// afterschool default.

/// The shared intent vocabulary — a CLOSED set. Every control surface
/// (tap, keyboard, the teacher's remote, a contributor phone) emits only
/// these, so a teacher learns the controls once and a new game inherits
/// them for free. Adding one is a framework decision, not a per-game one.
enum GameIntent {
  /// Advance — next slide / question / word / round.
  next,

  /// Step back. A no-op for games that don't rewind (Rhyme Time, As-If).
  back,

  /// Show / toggle the hidden beat — the answer, or a discussion prompt.
  reveal,

  /// A discrete host choice — `args: {'choice': int|String}`. The only
  /// intent that carries a selection (a vote side, a bracket pick).
  pick,

  /// Count one more of the room's responses — `args: {'by': int}` (default
  /// 1), optional `{'bucket': String}`. The heart of the host-present,
  /// teacher-tallies model.
  tally,

  /// Record durable evidence — `args: {'text': String, ...}`. Pure here
  /// (mutates state only); the durable write is a runner side-effect.
  capture,

  /// A contributor submission from a participant device (a Board sticky, a
  /// word-cloud word, a dropped pin) — `args` carries the contribution.
  /// The every-phone counterpart to [tally]; most afterschool games use
  /// [tally] (no kid devices), [submit] is there when devices are present.
  submit,

  /// Play again / new round.
  reset,
}

/// A pure transform over the wire-state. Identical in shape to the
/// existing `LiveReducer`, so a game's [GameDefinition.reduce] tear-off
/// drives both the single-device runner and a live session with no
/// adapter. Operates on `Map<String, dynamic>` (the wire-state) so it
/// survives the Realtime wire and stays JSON-trivial.
typedef GameReducer =
    Map<String, dynamic> Function(
      Map<String, dynamic> state,
      GameIntent intent,
      Map<String, dynamic> args,
    );

/// Where a [GameIntent.capture] / [GameIntent.submit] writes its durable
/// evidence (docs/GAMES.md). The intent stays pure; the runner performs
/// the write as a side effect, presenter-only in a live session.
enum CaptureTarget { crowdGrow, entry, both }

/// Declares that a game's `capture` produces durable evidence.
class CaptureSpec {
  const CaptureSpec({required this.target, required this.contentKind});

  /// crowd-grow into `content_items`, a growth-book `entries` row, or both.
  final CaptureTarget target;

  /// The bank kind to crowd-grow into (e.g. `ContentKind.rhymeWord`).
  final String contentKind;
}

/// Per-game character (docs/GAMES.md decision: a distinct vibe + hero
/// shape per game). The [GameDefinition.buildStage] owns the hero shape +
/// the per-game wrap beat; this carries the chrome tint the shared
/// scaffold reads (progress accent, control-bar wash, status pill).
/// The harmonized game-accent palette (Calm, on-brand). Eight accents drawn
/// from / harmonized with the brand (teal seed + warm amber tertiary),
/// desaturated to sit calm on the dark stage. Every [GameVibe] picks ONE from
/// here — no more ad-hoc per-game hex — so the deck reads as one system.
abstract final class GameAccents {
  static const teal = Color(0xFF2A9D8F);
  static const deepTeal = Color(0xFF1D7A6E);
  static const amber = Color(0xFFC79A3E);
  static const coral = Color(0xFFD8693C);
  static const plum = Color(0xFF7C6BAE);
  static const slate = Color(0xFF5784A8);
  static const rose = Color(0xFFC25E7E);
  static const sage = Color(0xFF5E9E6B);
}

/// The shared calm game surface — one warm near-black field for every stage,
/// so stages stop each inventing their own background tint.
const Color kGameSurface = Color(0xFF10100F);

class GameVibe {
  const GameVibe({required this.accent, this.surface = kGameSurface});

  /// The game's signature accent — pick ONE from [GameAccents] so the deck
  /// stays a harmonized, on-brand set (no ad-hoc hex).
  final Color accent;

  /// The stage background. Defaults to the shared [kGameSurface]; override
  /// only for a genuinely distinct field (e.g. This-or-That's per-slide split).
  final Color surface;
}

/// Everything that makes one game. Pure data + pure functions — the
/// widgets own no game state. `S` is the game's typed state view; the
/// wire-state is always `Map<String, dynamic>` so the reducer can also
/// run over Supabase Realtime.
abstract class GameDefinition<S> {
  const GameDefinition();

  /// Stable id — matches the route + the `ContentKind` where 1:1.
  String get id;

  /// Human title for the lobby / live header (e.g. "This or That").
  String get title;

  /// Per-game character (color/surface). The stage carries the rest.
  GameVibe get vibe;

  /// Build the initial wire-state. THE ONE place a game reads content, so
  /// the reducer stays pure + content-free. Stash content-derived data
  /// (e.g. the resolved pairs/words AND the item count under `'n'`) into
  /// the state here so the reducer needs no closure over content — and so
  /// the wire-state is self-describing on the live path (the presenter
  /// builds it from content + broadcasts it; controllers render the same
  /// data with no cross-device content-ordering assumption).
  ///
  /// The default control bar `GameScaffold` renders reads four CONVENTIONAL
  /// keys when present: `'i'` (current index, int), `'n'` (total, int),
  /// `'d'` (done, bool), `'r'` (revealed, bool). A game that follows the
  /// convention inherits the standard progress + Back/Reveal/Next/Again
  /// bar for free; one that doesn't overrides [buildControls].
  Map<String, dynamic> initialState(ContentSource content);

  /// Tunable params shown in a pre-game settings sheet (docs/FEATURE_CHECKLISTS
  /// — the Settings contract). Empty = no settings (the default). A game with
  /// knobs (number range, topics, count) returns them here and overrides
  /// [initialStateFor] to honor the chosen values.
  List<GameSetting> get settings => const [];

  /// Build the initial state honoring teacher-chosen [values] (keyed by
  /// `GameSetting.id`). Defaults to the no-settings path; games with [settings]
  /// override this to thread the values into their content. "Play again"
  /// re-runs this with the same chosen values, so a tuned round stays tuned.
  Map<String, dynamic> initialStateFor(
    ContentSource content,
    Map<String, Object?> values,
  ) => initialState(content);

  /// Typed lens over the wire-state — what a `fromMap` factory does.
  S decode(Map<String, dynamic> state);

  /// THE reducer — pure `(state, intent, args) -> state`. One function for
  /// both the local and live paths. Never touches content, Drift, or the
  /// network (those are runner concerns).
  Map<String, dynamic> reduce(
    Map<String, dynamic> state,
    GameIntent intent,
    Map<String, dynamic> args,
  );

  /// Which intents are live for the given state — drives which control
  /// affordances the scaffold shows + which keys bind (Back off at the
  /// start, Reveal off when done, …).
  Set<GameIntent> activeIntents(S state);

  /// The STAGE — a first-class, full-bleed, pluggable slot. Renders the
  /// state big for the room: text-on-black, a two-tone split, a big
  /// letter, a grid, a word cloud, (later) a map. Owns its hero shape +
  /// its own per-game wrap / done beat (docs/GAMES.md decision).
  Widget buildStage(BuildContext context, S state);

  /// Optional FULL override of the control region. When non-null the game
  /// renders its own buttons — a poll's per-option +1, a timer's start/pause,
  /// Charades' Got it/Skip — and calls `send` with the intent (+ optional
  /// args, e.g. `{'choice': i}`). Null = the scaffold's standard bar built
  /// from [activeIntents]. The scaffold supplies the bar chrome; the game
  /// owns what's inside. Used identically on the single-device and live
  /// control surfaces, so a custom-control game is controllable AND live.
  Widget? buildControls(
    BuildContext context,
    S state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) => null;

  /// Whether this game has a secret/actor role (drives the "Join as actor"
  /// lobby option + the controller-sees-the-secret behavior). Override to
  /// true alongside [buildSecretStage]. Default false = a normal two-role
  /// (present + control) game.
  bool get hasSecretRole => false;

  /// Optional stage for the SECRET (actor) role — a phone that mirrors the
  /// state but shows what the ROOM must not (e.g. Charades' secret word). When
  /// non-null, the live screen offers a "Join as actor" role that renders this,
  /// and the CONTROLLER (the teacher) sees this instead of [buildStage] (so
  /// they can mark the room's guess). The presenter/room always shows
  /// [buildStage]. Default null = no secret role (the normal two-role game).
  ///
  /// Secrecy is by RENDERING, not by the wire: the presenter builds the state
  /// (it already holds the content) and broadcasts it; the room device simply
  /// doesn't draw the secret field. So stash the secret content in
  /// [initialState] like any other content.
  Widget? buildSecretStage(BuildContext context, S state) => null;

  /// The label for the [GameIntent.reveal] button in the default control
  /// bar. Most games "Reveal"; This-or-That "Discuss" (it reveals a
  /// discussion prompt, not an answer).
  String revealLabel({required bool revealed}) => revealed ? 'Hide' : 'Reveal';

  /// If non-null, the scaffold shows a "cast" action that pushes this route
  /// — the live present/control variant (docs/LIVE_SESSIONS.md).
  String? get liveRoute => null;

  /// Whether this game builds its whole round from the content bank in
  /// [initialState] (true) — vs. needing a Drift-derived seed (roster,
  /// schedule) the content bank can't supply (false). The cast launcher
  /// (docs/LIVE_SESSIONS.md "the cast model") only offers `true` games, since
  /// it seeds purely from the content bank; a `false` game would cast an empty
  /// stage. Default true; data-seeded presentables (Now & Next, Spotlight)
  /// override to false until the cast flow can pass them a seed.
  bool get seedsFromContentBank => true;

  /// If non-null, `capture` / `submit` produce durable evidence and the
  /// runner routes the write here (crowd-grow + a growth-book entry).
  CaptureSpec? get capture => null;
}
