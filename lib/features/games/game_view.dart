import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/facilitation/run_script_view.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/games/arrives.dart';
import 'package:differentworld/features/games/celebration.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_motion.dart';
import 'package:differentworld/features/games/round_wrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **The one thing that draws a game.**
///
/// Four surfaces render a game from its wire-state — the single-device
/// scaffold, the cast receiver (a TV), the cast cockpit (the phone driving
/// that TV) and the two-device live screen — and each of them used to answer
/// "what do I draw" for itself. Two remembered to check for the briefing and
/// two did not, which is not a style problem: casting a scripted game put
/// beat one on the television, a board on the phone, and NO way to advance,
/// because a board game's live verbs are `pick` (swallowed during a briefing)
/// and `reset`. The room read "We are playing Connect Four" until somebody
/// gave up. Two of four surfaces is exactly the hit rate you get when the
/// same decision is written four times.
///
/// So the decision lives here, once. A surface says WHO is looking
/// ([GameAudience]) and gets the briefing, the stage, the celebration, the
/// motion, the sound and the haptics resolved together — because those are
/// not six independent choices, they are one answer to "whose screen is
/// this". Chrome around it (a control bar, a wrap beat, a session header)
/// stays the surface's own business.
class GameView extends ConsumerWidget {
  const GameView({
    required this.def,
    required this.wire,
    required this.audience,
    this.send,
    this.onDone,
    super.key,
  });

  final GameDefinition<dynamic> def;

  /// The wire-state — a game's whole truth, briefing cursor included.
  final Map<String, dynamic> wire;

  final GameAudience audience;

  /// How this surface talks back. Required for an audience that drives; a
  /// display passes null and the view renders no verbs of its own.
  final void Function(GameIntent intent, [Map<String, dynamic> args])? send;

  /// Leave the game — pop the route, exit fullscreen, return to the cast
  /// launcher. Null where a surface has nowhere to send you (a live session
  /// ends from its own header), and the wrap beat drops its Done button.
  final VoidCallback? onDone;

  /// Whether this wire-state is showing the rules rather than the game.
  ///
  /// A caller asks so it can drop its own chrome — a control bar under a
  /// briefing offers verbs for a board nobody can see yet.
  static bool isBriefing(Map<String, dynamic> wire) =>
      RunScriptWire.indexOf(wire) != null;

  /// Whether the round is over, so a surface can drop its own chrome: a
  /// control bar under a finished board offers verbs for a game that is not
  /// being played any more, beneath the wrap beat that already carries the
  /// two that matter.
  static bool isEnded(Map<String, dynamic> wire) => wire['d'] == true;

  /// Whether this game draws its own TOUCHABLE board — Memory, Reveal the
  /// Picture, every classic — as opposed to a display the scaffold puts a
  /// control bar under.
  ///
  /// A layout question, and the only reason a surface would otherwise reach
  /// for `buildLiveStage` itself. It lives here so the two game layers have
  /// ONE vocabulary for asking about a game: `isBriefing`, `ownsStage`, and
  /// render `GameView`. Nothing else calls a `build*` — which is what stops
  /// a sixth surface quietly drawing a board over a briefing.
  ///
  /// False while briefing: the rules are nobody's instrument.
  static bool ownsStage(
    BuildContext context,
    GameDefinition<dynamic> def,
    Map<String, dynamic> wire,
  ) {
    if (isBriefing(wire)) return false;
    return def.buildLiveStage(context, def.decode(wire), _noSend) != null;
  }

  /// A sender that goes nowhere — for [ownsStage], which asks whether a
  /// widget WOULD be built and then throws it away.
  static void _noSend(
    GameIntent intent, [
    Map<String, dynamic> args = const {},
  ]) {}

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final motionOn = ref.watch(gameMotionProvider).value ?? true;
    return GameMotion(
      enabled: motionOn,
      haptics: audience.haptics,
      sound: audience.sound,
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    // The briefing FIRST, on every surface. The cursor is in the wire, so one
    // Next moves the phone and the television together.
    if (RunScriptWire.indexOf(wire) case final at?) {
      final surface = def.vibe.surface;
      return RunScriptView(
        script: def.howToPlay,
        index: at,
        title: def.title,
        surface: surface,
        // Content-driven fill, so no theme governs the foreground — pick by
        // luminance or the pale vibes get white on light.
        onLine: AppColors.onAccent(surface),
        // A display never advances the rules: two devices that can both move
        // the beat is two devices disagreeing about which rule the room heard.
        onNext: audience.drives ? () => send?.call(GameIntent.next) : null,
        onBack: audience.drives ? () => send?.call(GameIntent.back) : null,
      );
    }

    final state = def.decode(wire);
    // A game with a secret (Charades' word) shows it only where the room
    // cannot see: the host's own phone, or the remote driving the screen.
    final stage =
        (audience.seesSecret ? def.buildSecretStage(context, state) : null) ??
        // The board you look at is the board you touch — but only in a hand.
        // A room's screen is not an instrument; a tap there means nothing.
        (audience.touchable && send != null
            ? def.buildLiveStage(context, state, send!)
            : null) ??
        def.buildStage(context, state);

    final done = wire['d'] == true;
    final celebrated = CelebrationLayer(
      done: done,
      accent: def.vibe.accent,
      child: stage,
    );
    // A round that ENDED, wherever somebody can act on it.
    //
    // The ending was in as many shapes as the briefing had been: the
    // scaffold drew a `RoundWrap` for the board games and a different done
    // beat inside each of its two control bars for the rest, the cockpit drew
    // nothing at all — so a cast Connect Four froze on its winning line with
    // no way to play again short of casting it a second time — and the live
    // screen and fullscreen offered a bare "Again" with no closing line.
    // Three shapes, two absences, one question.
    //
    // A room's SCREEN gets no verbs: the board already says who won, and the
    // hand holding the phone is where Play again belongs.
    // ALWAYS a Column with the stage in an Expanded, even with nothing under
    // it. Returning the bare stage let it hug its content: a Connect Four
    // board sat at the top of the phone with the screen's own background
    // showing through below it, because the fill used to come from an
    // `Expanded` at the call site. A view that fills the space it is given is
    // the view's own business — every surface hands it a bounded box.
    return Column(
      children: [
        _RoundPosition(wire: wire, accent: def.vibe.accent),
        Expanded(child: celebrated),
        if (done && audience.drives)
          RoundWrap(
            key: const ValueKey('round-wrap'),
            line: def.outcomeLine(state),
            accent: def.vibe.accent,
            gameId: def.id,
            keepsake: def.keepsake(state),
            onAgain: () => send?.call(GameIntent.reset),
            onDone: onDone,
            onRules: def.howToPlay.isEmpty
                ? null
                : () => send?.call(GameIntent.reveal, {
                    RunScriptWire.rulesArg: true,
                  }),
          ),
      ],
    );
  }
}

/// Whose screen this is. Every difference between the four surfaces follows
/// from this one question, which is why it is asked once.
enum GameAudience {
  /// One device in a host's hand. It drives, its board is the instrument, it
  /// sees the secret (the room cannot see this screen), it buzzes and it
  /// sounds.
  host,

  /// A phone driving a room's screen. Like [host], except SILENT: the room's
  /// screen plays Simon's notes, and two devices playing them a beat apart is
  /// worse than one playing them alone.
  remote,

  /// The room's screen, driven from elsewhere. It draws and never drives; the
  /// secret never reaches it; it sounds (the room is listening) and it never
  /// buzzes — a tablet on a wall vibrating is a fault, not a feature.
  room,

  /// The room's screen that also holds the keys — the `/live` presenter. It
  /// draws the room's view (never the secret, never a touchable board) and
  /// drives from its own control bar.
  presenter;

  /// Whether this surface may move the game on.
  bool get drives => this != GameAudience.room;

  /// Whether the actor's secret may be drawn here.
  bool get seesSecret =>
      this == GameAudience.host || this == GameAudience.remote;

  /// Whether the board itself is the instrument here.
  bool get touchable =>
      this == GameAudience.host || this == GameAudience.remote;

  /// Whether the stage makes its sounds here.
  bool get sound => this != GameAudience.remote;

  /// Whether a tap buzzes here — a hand, never a wall.
  bool get haptics => this == GameAudience.host || this == GameAudience.remote;
}

/// **How far through the round the room is**, as a hairline that fills.
///
/// Eight games let a teacher choose the round length and then showed them
/// nothing: you pick eight letters, play, and cannot tell whether you are on
/// the second or the seventh. Deciding "do we have time for another" was
/// guesswork, and it got worse the moment the length became tunable.
///
/// DERIVED, not declared. The games already carry what it needs on the wire —
/// `'n'` for how many, and a position — so nothing is passed in and nothing
/// has to be remembered when a ninth game arrives. A game that carries no
/// position, or an `n` below two, draws nothing: `cues`, `picker`, the card
/// games and the Conductor all fall out on their own.
///
/// **Two real shapes, and conflating them draws the bar wrong by one step.**
/// Most of these step an INDEX (`'i'`, zero-based) through a fixed list, so
/// the room on prompt three of eight is three-eighths through. As If crosses
/// two lists instead and counts PERFORMANCES (`'p'`), which starts at zero
/// with nothing done — so `p` is already the completed fraction and must not
/// be incremented. `'p'` appears on no other game's wire, checked, so reading
/// it here cannot collide.
///
/// A hairline rather than "3 of 8": the question a teacher asks mid-round is
/// *nearly done?*, which a filled bar answers without being read, and the
/// stage below it is already carrying the words that matter.
class _RoundPosition extends StatelessWidget {
  const _RoundPosition({required this.wire, required this.accent});

  final Map<String, dynamic> wire;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final of = wire['n'];
    if (of is! num || of < 2) return const SizedBox.shrink();
    final index = wire['i'];
    final performed = wire['p'];
    final double done;
    if (index is num && index >= 0) {
      // An index: a room on the last prompt should see a full bar.
      done = ((index + 1) / of).clamp(0.0, 1.0);
    } else if (performed is num && performed >= 0) {
      // A count of what is finished: zero done is an empty bar.
      done = (performed / of).clamp(0.0, 1.0);
    } else {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 3,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: done,
          child: AnimatedContainer(
            duration: Arrives.duration,
            curve: Curves.easeOutCubic,
            color: accent,
          ),
        ),
      ),
    );
  }
}
