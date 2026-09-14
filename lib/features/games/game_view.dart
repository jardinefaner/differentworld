import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/facilitation/run_script_view.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/games/celebration.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_motion.dart';
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
    super.key,
  });

  final GameDefinition<dynamic> def;

  /// The wire-state — a game's whole truth, briefing cursor included.
  final Map<String, dynamic> wire;

  final GameAudience audience;

  /// How this surface talks back. Required for an audience that drives; a
  /// display passes null and the view renders no verbs of its own.
  final void Function(GameIntent intent, [Map<String, dynamic> args])? send;

  /// Whether this wire-state is showing the rules rather than the game.
  ///
  /// A caller asks so it can drop its own chrome — a control bar under a
  /// briefing offers verbs for a board nobody can see yet.
  static bool isBriefing(Map<String, dynamic> wire) =>
      RunScriptWire.indexOf(wire) != null;

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

    return CelebrationLayer(
      done: wire['d'] == true,
      accent: def.vibe.accent,
      child: stage,
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
