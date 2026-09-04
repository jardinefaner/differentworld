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
/// The harmonized game-accent palette (Calm, on-brand). Eight accents, all
/// pulled to ONE muted tone (consistent saturation + value) so the deck reads
/// as a designed set, not a rainbow — the loud warm ones (amber, coral) are
/// brought down to match the calm cool ones; `coral` is now an earthier clay.
/// Every [GameVibe] picks ONE from here — no ad-hoc per-game hex — so the deck
/// is one system. (Tightened from the original brighter set, 2026-06-16.)
abstract final class GameAccents {
  static const teal = Color(0xFF3E8E81);
  static const deepTeal = Color(0xFF327C70);
  static const amber = Color(0xFFB6924F);
  static const coral = Color(0xFFBC6E50);
  static const plum = Color(0xFF8076A6);
  static const slate = Color(0xFF5E82A0);
  static const rose = Color(0xFFB06A82);
  static const sage = Color(0xFF67976E);
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

  /// The stage when it can be TOUCHED — the single-device layout, where the
  /// display IS the instrument.
  ///
  /// A game whose stage has something to point at (a card to flip, a tile to
  /// reveal) used to draw its board TWICE on a phone: full-size and dead on
  /// the stage, then again as a row of ~15pt thumbnails in [buildControls] so
  /// there was something to tap. That split is real when CASTING — the TV
  /// holds the display and the phone is genuinely a remote — but on one
  /// device it asks a staffer to look at one board and touch a different one,
  /// and spends a quarter of the screen doing it. Reveal the Picture even
  /// grew an A1–D4 coordinate system whose only job was mapping one copy onto
  /// the other.
  ///
  /// Return the COMPLETE single-device layout here, verbs included — the
  /// scaffold renders it instead of [buildStage] + [buildControls], so the
  /// game owns the whole shape rather than negotiating with a control bar.
  ///
  /// Null (the default, and right for most games) means this stage has
  /// nothing to tap: a riddle, a prompt, a countdown. Those keep the standard
  /// stage + control bar.
  ///
  /// [buildStage] stays untouched and stays a pure display, because it is
  /// also what the cast RECEIVER paints on the TV — where a tap must never
  /// mean "play a card", and already means something else.
  Widget? buildLiveStage(
    BuildContext context,
    S state,
    void Function(GameIntent intent, [Map<String, dynamic> args]) send,
  ) => null;

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

/// The shared advance/back/reveal/reset reducer for the picture-DECK games
/// (Name It, Odd One Out) — the `i/d/r` state machine over a list of items
/// stashed under [itemsKey] (`'cards'`, `'rounds'`), with the total derived
/// from that list's length. Reveal SHOWS (no toggle); Back un-dones. Only
/// games whose reducer matches this byte-for-byte should delegate here —
/// ones with extra beats (phases, tallies, twists) keep their own.
Map<String, dynamic> deckReduce(
  Map<String, dynamic> state,
  GameIntent intent, {
  required String itemsKey,
}) {
  final s = Map<String, dynamic>.from(state);
  final n = (s[itemsKey] as List? ?? const []).length;
  final i = (s['i'] as num?)?.toInt() ?? 0;
  switch (intent) {
    case GameIntent.next:
      if (i < n - 1) {
        s['i'] = i + 1;
        s['r'] = false;
      } else {
        s['d'] = true;
      }
    case GameIntent.back:
      if (i > 0) {
        s['i'] = i - 1;
        s['r'] = false;
        s['d'] = false;
      }
    case GameIntent.reveal:
      s['r'] = true;
    case GameIntent.reset:
      s['i'] = 0;
      s['r'] = false;
      s['d'] = false;
    case GameIntent.pick:
    case GameIntent.tally:
    case GameIntent.capture:
    case GameIntent.submit:
      break;
  }
  return s;
}

/// The shared reducer for the REVEAL-template games (Riddles, Fact or Fib)
/// — `i/n/d/r` with the total carried under `'n'`, a TOGGLING reveal
/// (guarded while done), and Back stepping out of the done recap. Only
/// games whose reducer matches this byte-for-byte should delegate here
/// (This-or-That's reveal toggles even when done, so it keeps its own).
Map<String, dynamic> revealDeckReduce(
  Map<String, dynamic> state,
  GameIntent intent,
) {
  final s = Map<String, dynamic>.from(state);
  final i = (s['i'] as num?)?.toInt() ?? 0;
  final n = (s['n'] as num?)?.toInt() ?? 1;
  final done = s['d'] == true;
  switch (intent) {
    case GameIntent.reveal:
      if (!done) s['r'] = !(s['r'] == true);
    case GameIntent.next:
      if (done) break;
      if (i >= n - 1) {
        s['d'] = true;
      } else {
        s['i'] = i + 1;
        s['r'] = false;
      }
    case GameIntent.back:
      if (done) {
        s['d'] = false;
      } else if (i > 0) {
        s['i'] = i - 1;
        s['r'] = false;
      }
    case GameIntent.reset:
      s['i'] = 0;
      s['r'] = false;
      s['d'] = false;
    case GameIntent.pick:
    case GameIntent.tally:
    case GameIntent.capture:
    case GameIntent.submit:
      break;
  }
  return s;
}

/// The shared done-state control row — a right-aligned "Play again" that
/// sends [GameIntent.reset]. For games that override [GameDefinition.buildControls]
/// and land on the standard wrap beat (Charades, Story Starters).
Widget playAgainControls(
  void Function(GameIntent intent, [Map<String, dynamic> args]) send,
) {
  return Row(
    children: [
      const Spacer(),
      FilledButton.icon(
        onPressed: () => send(GameIntent.reset),
        icon: const Icon(Icons.replay),
        label: const Text('Play again'),
      ),
    ],
  );
}
