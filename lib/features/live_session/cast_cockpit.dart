import 'dart:async';
import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/action_words/conductor.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/world_cast_game.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/facilitation/room_tools.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_clock.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/features/games/game_settings_sheet.dart';
import 'package:differentworld/features/games/game_view.dart';
import 'package:differentworld/features/games/games/nownext_game.dart';
import 'package:differentworld/features/games/games/picker_game.dart';
import 'package:differentworld/features/games/games/timer_game.dart';
import 'package:differentworld/features/live_session/cast_seeding.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:differentworld/features/live_session/cast_session_controller.dart';
import 'package:differentworld/features/live_session/cast_stage_chrome.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/shared/widgets/accent_card_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The **Cockpit** — the phone as the app remote (docs/LIVE_SESSIONS.md "the
/// cast model"). The authority: it picks what to present (the launcher),
/// drives it (the controls), and switches it at will. Everything here stays on
/// the phone — only the chosen game + its state ride the wire to the Receiver.
///
/// **It is THEMED, because it is a remote and not a stage.** It spent a long
/// time on the raw-canvas allowlist, painted near-black with white text and
/// its own palette, under a comment in `cast_screen` calling it "a projection
/// stage (the TV)". Nothing here is ever on a TV: the sentence above says so,
/// and the Receiver is the thing the room looks at. The effect was that
/// tapping "This is my remote" dropped you out of a warm cream app into a
/// black one — the same screen, the same hand, a different product.
///
/// The one genuinely raw region is [_Driving]'s preview, which mirrors what
/// the TV is showing and keeps the game's own `vibe.surface`. That is the
/// boundary docs/THEME_ADHERENCE.md draws: the stage is raw, the controls
/// around it are not.
class CastCockpit extends ConsumerStatefulWidget {
  const CastCockpit({
    required this.code,
    required this.onLeave,
    this.castOnConnect,
    super.key,
  });

  final String code;

  /// A game id to put on the screen as soon as this cockpit is live.
  ///
  /// Carries the intent from wherever the cast was ASKED for. "Put Riddle Me
  /// This on the TV" used to become a bare `/cast`, so the cockpit opened
  /// having forgotten the riddle and the staffer had to find it again in the
  /// launcher — the app asking a question it had already been told the answer
  /// to.
  final String? castOnConnect;
  final VoidCallback onLeave;

  @override
  ConsumerState<CastCockpit> createState() => _CastCockpitState();
}

class _CastCockpitState extends ConsumerState<CastCockpit> {
  // The session is owned by [castSessionProvider] — it persists across
  // navigation (the anchor). The cockpit only DRIVES it. These two flags are
  // phone-local UI state.
  bool _errorBannerDismissed = false;
  // The launcher is the home; casting hides it, "Switch" brings it back. It's
  // phone-local — opening it never changes what the screen is showing.
  bool _showLauncher = true;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable()); // the remote shouldn't sleep mid-session
    // Become the authority on this code (idempotent — reuses the live session
    // if we're already casting it). Deferred off the build phase: the chrome
    // pill watches this provider, and writing a watched provider mid-build is
    // the "modified provider while the widget tree was building" trap.
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        ref.read(castSessionProvider.notifier).start(widget.code);
        final pending = widget.castOnConnect;
        if (pending == null) return;
        final def = gameById(pending);
        // An id this build doesn't know is not an error worth a dialog — the
        // cockpit simply opens on its launcher, which is where the staffer
        // would have gone anyway.
        if (def == null) return;
        unawaited(_castSeeded(def));
      }),
    );
  }

  /// The cast is the authority (docs/LIVE_SESSIONS.md), so the cockpit winds
  /// the clock for whatever is on the screen. Nothing did before, so Whack-a-
  /// Mole, Simon and Boggle cast a still picture to the room: the mole never
  /// moved, the sequence never played, the sand never ran out.
  final _clock = GameClock();

  @override
  void dispose() {
    _clock.stop();
    unawaited(WakelockPlus.disable());
    // Do NOT dispose the session — it lives in castSessionProvider so the cast
    // PERSISTS when we leave (only an explicit Stop ends it). The anchor.
    super.dispose();
  }

  /// What the teacher chose, per game id. Held here rather than on the wire:
  /// the values shape the SEED, and a room screen renders the seeded state —
  /// it never needs to know which knob produced it.
  final Map<String, Map<String, Object?>> _values = {};

  /// Tune the game that is currently cast, then re-cast it with the choice.
  /// Between rounds, which is act one — never mid-play (docs/CONDITIONS.md).
  Future<void> _tune(GameDefinition<dynamic> def) async {
    final result = await showGameSettings(
      context,
      settings: def.settings,
      initial: _values[def.id] ?? defaultSettingValues(def.settings),
    );
    if (result == null || !mounted) return;
    setState(() => _values[def.id] = result);
    await _castSeeded(def);
  }

  CastSessionController get _cast => ref.read(castSessionProvider.notifier);

  /// **Put a game on the screen.** The only door in the cockpit — opening with
  /// a game, picking a tile, tuning a knob and Play again all come here, and
  /// [castSeedFor] is the only thing that decides what the first round holds.
  ///
  /// There were four doors and each carried its own answer: three of them knew
  /// the content bank and nothing else, so tuning, re-opening or replaying a
  /// deck-, roster- or schedule-seeded game emptied the room's screen — while
  /// the launcher two methods away seeded the same game correctly.
  Future<void> _castSeeded(GameDefinition<dynamic> def) async {
    final cast = _cast; // capture before the await — ref may be gone after
    final seed = await castSeedFor(
      CastData.ofRef(ref),
      def,
      values: _values[def.id],
    );
    if (seed == null || !mounted) return;
    cast.castStage(def.id, seed);
    setState(() => _showLauncher = false);
  }

  /// Cast the live curriculum world — an explicit-seed presentable, not a
  /// content-bank game, so it goes through castStage (docs/WORLD.md).
  void _castWorld(CurriculumWorld world) {
    _cast.castStage(WorldCastGame.gameId, worldCastSeed(world));
    setState(() => _showLauncher = false);
  }

  /// Conduct any text — paste lyrics / a sentence, cast it, then tap a word
  /// to spotlight it on the screen (the Conductor).
  Future<void> _castConductor() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ConductSheet(),
    );
    if (text == null || text.trim().isEmpty) return;
    _cast.castStage(ConductorGame.gameId, conductorSeed(text));
    if (mounted) setState(() => _showLauncher = false);
  }

  void _send(GameIntent intent, [Map<String, dynamic> args = const {}]) {
    final id = CastSession.gameIdOf(ref.read(castSessionProvider).meta);
    final def = id == null ? null : gameById(id);
    // "Play again" re-casts with a FRESH seed (the pure reducer can't pull
    // new content); everything else reduces on the authority. Through the same
    // door as every other cast — this one used to reach only the content bank,
    // so replaying a cast Name It or Spotlight emptied the room's screen.
    if (intent == GameIntent.reset && def != null) {
      unawaited(_castSeeded(def));
    } else {
      _cast.send(intent, args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = ref.watch(castSessionProvider);
    // Re-arm the solo banner on each fresh transition INTO error.
    ref.listen(castSessionProvider, (prev, next) {
      if (next.status == LiveStatus.error &&
          (prev?.status ?? LiveStatus.connecting) != LiveStatus.error) {
        setState(() => _errorBannerDismissed = false);
      }
    });
    final gameId = CastSession.gameIdOf(snap.meta);
    final def = gameId == null ? null : gameById(gameId);
    // Follow whatever is cast. Cheap for the ~40 games with no clock (no timer
    // is created), and re-pointing at the game already running is a no-op, so
    // this is safe to call on every build.
    _clock.follow(def, () => _send(GameIntent.tick));
    // The live world is the one thing a stranded caster can still present
    // locally (the present screen runs without a Receiver). Null when the
    // journey isn't set up → the banner falls back to a "check the code" hint.
    final world = ref.watch(currentWorldProvider);

    return PopScope(
      // Driving a game, back returns to the launcher — the same thing the
      // Switch button does. Without this the pop fell through to CastScreen,
      // which sent you to the LOBBY: a setup screen asking "which device is
      // this one?" while you are actively casting from this one.
      canPop: def == null || _showLauncher,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _showLauncher = true);
      },
      child: _body(context, snap, def, world),
    );
  }

  Widget _body(
    BuildContext context,
    CastSnapshot snap,
    GameDefinition<dynamic>? def,
    CurriculumWorld? world,
  ) {
    return Column(
      children: [
        _CockpitHeader(
          status: snap.status,
          peers: snap.peers,
          code: widget.code,
          casting: def?.title,
          onLeave: widget.onLeave,
          onStop: () {
            _cast.stop();
            widget.onLeave();
          },
        ),
        // No second screen / lost the link? Don't strand the teacher driving a
        // dead cast — offer to show this week's world on just this device.
        if (snap.status == LiveStatus.error && !_errorBannerDismissed)
          _CastErrorBanner(
            onDismiss: () => setState(() => _errorBannerDismissed = true),
            onSolo: world == null
                ? null
                : () => unawaited(context.push('/present-world/${world.id}')),
          ),
        // The explicit `def == null` here promotes `def` to non-null in the
        // else branch (no `!` needed).
        if (def == null || _showLauncher)
          Expanded(
            key: const ValueKey('cockpit-launcher'),
            child: _Launcher(
              onPick: (def) => unawaited(_castSeeded(def)),
              presentWorld: world,
              onPresentWorld: _castWorld,
              onConduct: _castConductor,
            ),
          )
        else ...[
          Expanded(
            key: const ValueKey('cockpit-driving'),
            child: _Driving(
              def: def,
              meta: snap.meta,
              send: _send,
              // "Done" on a cast returns to the launcher rather than ending
              // the session — the screen stays yours, you just pick the next
              // thing. A finished cast round had no verb at all before this.
              onDone: () => setState(() => _showLauncher = true),
            ),
          ),
          _SwitchBar(
            // Only when the game HAS knobs — an empty sheet is a button that
            // lies about what it can do.
            onTune: def.settings.isEmpty ? null : () => unawaited(_tune(def)),
            onSwitch: () => setState(() => _showLauncher = true),
            onStop: () {
              _cast.clearStage();
              setState(() => _showLauncher = true);
            },
          ),
        ],
      ],
    );
  }
}

/// Shown in the cockpit when the session can't reach a Receiver
/// (`LiveStatus.error`). The degraded-mode escape hatch: rather than tap into
/// a void, the teacher can present this week's world on this device alone (the
/// present screen runs fully local, no Receiver needed). Dismissible — a blip
/// shouldn't nag — and re-armed if the link drops again.
class _CastErrorBanner extends StatelessWidget {
  const _CastErrorBanner({required this.onDismiss, this.onSolo});

  final VoidCallback onDismiss;

  /// Null when there's no live world to fall back to (journey not set up).
  final VoidCallback? onSolo;

  @override
  Widget build(BuildContext context) {
    final canSolo = onSolo != null;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.error),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              canSolo
                  ? "Can't reach the screen. Show it on just this device "
                        'instead?'
                  : "Can't reach the screen. Check the join code on the "
                        'other device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (canSolo) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onSolo,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Show here'),
            ),
          ],
          IconButton(
            tooltip: 'Dismiss',
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 20,
            ),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// The launcher — pick what to cast. The whole game deck, by vibe colour.
/// **What the launcher lists, once each.** A game is here unless it needs a
/// choice the launcher can't make ([GameDefinition.needsCallerSeed] — the
/// world, the Conductor, the Live Board) or already has a tile of its own
/// above, where a real subtitle reads better than "Tap to cast".
///
/// It is derived from the registry rather than hand-listed, so a new game is
/// castable the moment it is registered — the old predicate was
/// `seedsFromContentBank`, which silently left every deck-, roster- and
/// schedule-seeded game out of the room's reach.
final List<GameDefinition<dynamic>> launcherGames = <GameDefinition<dynamic>>[
  for (final def in liveGames)
    if (!def.needsCallerSeed && !_ownTileIds.contains(def.id)) def,
];

final Set<String> _ownTileIds = <String>{
  const NowNextGame().id,
  const PickerGame().id,
  const TimerGame().id,
};

class _Launcher extends StatelessWidget {
  const _Launcher({
    required this.onPick,
    this.presentWorld,
    this.onPresentWorld,
    this.onConduct,
  });

  final void Function(GameDefinition<dynamic>) onPick;

  /// The live curriculum world (null if the journey isn't set up). Offered
  /// as a special "presentable" tile — it's explicit-seeded, not a content-
  /// bank game, so it can't ride the standard loop below.
  final CurriculumWorld? presentWorld;
  final void Function(CurriculumWorld world)? onPresentWorld;

  /// Open the Conduct text-entry (cast any text, then tap words to spotlight).
  final VoidCallback? onConduct;

  @override
  Widget build(BuildContext context) {
    // Same sizing as the activity library's grid, and for the same reason its
    // comment gives: these tiles are top-aligned with no Spacer, so a cell
    // tuned for a stretched layout leaves ~40% of every tile empty. Fixed
    // chrome (padding + icon + gap) plus a text block that grows with the
    // user's text scale.
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return GridView.extent(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      maxCrossAxisExtent: 220,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      mainAxisExtent: 72 + 64 * scale,
      children: [
        // This week's world — first, the headline thing to cast.
        if (presentWorld case final world? when onPresentWorld != null)
          _WorldTile(world: world, onTap: () => onPresentWorld!(world)),
        // The Conductor — cast any text and tap words to spotlight them.
        if (onConduct != null)
          _SimpleTile(
            icon: Icons.ads_click,
            title: 'Conduct',
            subtitle: 'Cast text, tap a word',
            color: ActivityPalette.teal,
            onTap: onConduct!,
          ),
        // Now & Next — today's schedule on the screen, advanced from the phone.
        _SimpleTile(
          icon: Icons.view_agenda_outlined,
          title: 'Now & Next',
          subtitle: "Today's schedule",
          color: ActivityPalette.green,
          onTap: () => onPick(const NowNextGame()),
        ),
        // Spotlight — fair turns, on the screen the room is watching. The
        // bag rides the wire, so the TV and the phone agree about who is left.
        _SimpleTile(
          icon: Icons.casino_outlined,
          title: 'Spotlight',
          subtitle: 'Pick a name, fairly',
          color: ActivityPalette.amber,
          onTap: () => onPick(const PickerGame()),
        ),
        // Visual Timer — a countdown on the screen, driven from the phone.
        _SimpleTile(
          icon: Icons.timer_outlined,
          title: 'Timer',
          subtitle: 'A countdown on the screen',
          color: ActivityPalette.blue,
          onTap: () => onPick(const TimerGame()),
        ),
        // Everything else, once each. This used to be two loops — content-bank
        // games, then the deck-seeded card games — and Bingo, Guess Who and
        // Spot the Difference are in BOTH lists, so each appeared twice and one
        // of the two tiles cast a board of placeholder stars. One list, and
        // `castSeedFor` finds the right seed behind whichever tile you tap.
        for (final def in launcherGames)
          _LauncherTile(def: def, onTap: () => onPick(def)),
      ],
    );
  }
}

/// A non-game launcher tile (the Conductor, future presentables).
///
/// Delegates to [AccentCardTile] — the same tile the activity library draws —
/// so "what can I put on the screen" and "what can we do together" are
/// recognisably the same list of things, rather than one warm and one black.
class _SimpleTile extends StatelessWidget {
  const _SimpleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AccentCardTile(
      color: color,
      icon: icon,
      title: title,
      tagline: subtitle,
      onTap: onTap,
    );
  }
}

/// Paste / type the text to conduct.
class _ConductSheet extends StatefulWidget {
  const _ConductSheet();

  @override
  State<_ConductSheet> createState() => _ConductSheetState();
}

class _ConductSheetState extends State<_ConductSheet> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Conduct', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Paste lyrics or type a sentence — one line per line. Tap a word '
              'on the screen to spotlight it.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              style: Theme.of(context).textTheme.bodyLarge,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Twinkle twinkle little star…',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(_text.text),
              icon: const Icon(Icons.cast),
              label: const Text('Cast it'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldTile extends StatelessWidget {
  const _WorldTile({required this.world, required this.onTap});

  final CurriculumWorld world;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AccentCardTile(
      color: world.color,
      emoji: world.emoji,
      title: world.name,
      tagline: 'Week ${world.week} · tap to cast',
      onTap: onTap,
    );
  }
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({required this.def, required this.onTap});

  final GameDefinition<dynamic> def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The game's own accent, tinted rather than filled — the same tile the
    // activity library draws, so the deck reads as one deck wherever it is
    // listed.
    return AccentCardTile(
      color: def.vibe.accent,
      icon: Icons.cast,
      title: def.title,
      tagline: 'Tap to cast',
      onTap: onTap,
    );
  }
}

/// Driving a cast game: the stage (what the room sees) + its controls.
class _Driving extends StatelessWidget {
  const _Driving({
    required this.def,
    required this.meta,
    required this.send,
    required this.onDone,
  });

  final GameDefinition<dynamic> def;
  final Map<String, dynamic> meta;
  final void Function(GameIntent, [Map<String, dynamic>]) send;

  /// Back to the launcher when a round is over.
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final wire = CastSession.gameStateOf(meta);
    // The board you look at is the board you touch — here too. The preview
    // fills most of the phone already, so a second copy of it at thumbnail
    // size underneath is the same redundancy the single-device screens had,
    // just with a longer excuse: "the TV holds the display" is true, and
    // irrelevant to the fact that the display is ALSO right here in your hand.
    //
    // `remote`: it drives, it touches, it sees a secret, and it stays SILENT
    // so the room's screen is the one that sounds.
    final view = GameView(
      def: def,
      wire: wire,
      audience: GameAudience.remote,
      send: send,
      onDone: onDone,
    );
    // While the room is being briefed the phone shows the SAME beats, with
    // the Next that moves them. It used to show the board instead — and for a
    // board game that board's only verbs are a tap the briefing swallows and
    // a reset, so the room sat on beat one with no way forward at all.
    if (GameView.isBriefing(wire)) return view;

    if (GameView.ownsStage(context, def, wire)) return view;

    final state = def.decode(wire);
    final custom = def.buildControls(context, state, send);
    return Column(
      children: [
        Expanded(
          child: ColoredBox(color: def.vibe.surface, child: view),
        ),
        // A finished round belongs to the wrap beat; a bar of verbs for a
        // board that is over is the duplicate ending this layer just stopped
        // having.
        if (GameView.isEnded(wire))
          const SizedBox.shrink()
        else if (custom != null)
          CastBar(child: custom)
        else
          GameIntentBar(def: def, wire: wire, onIntent: send),
      ],
    );
  }
}

class _SwitchBar extends StatelessWidget {
  const _SwitchBar({
    required this.onSwitch,
    required this.onStop,
    this.onTune,
  });

  final VoidCallback onSwitch;
  final VoidCallback onStop;

  /// Tune this game — null when it has no settings.
  final VoidCallback? onTune;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              // Pick a name, start a timer, flash "eyes up" — WITHOUT
              // clearing the cast. This is facet 5 of the facilitation
              // engine, and the cockpit was the surface it had never reached:
              // a counselor mid-cast who needed a name had to stop the
              // screen, walk back to the deck and lose the room's place,
              // which is the exact problem Room tools exists to end. The
              // cast survives the push — the session lives in the provider,
              // not in this widget.
              const RoomToolsButton(compact: true),
              const SizedBox(width: 4),
              if (onTune case final tune?) ...[
                IconButton.outlined(
                  onPressed: tune,
                  icon: const Icon(Icons.tune),
                  tooltip: 'Game settings',
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSwitch,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Cast something else'),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: onStop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CockpitHeader extends StatelessWidget {
  const _CockpitHeader({
    required this.status,
    required this.peers,
    required this.code,
    required this.casting,
    required this.onLeave,
    required this.onStop,
  });

  final LiveStatus status;
  final int peers;
  final String code;
  final String? casting;
  final VoidCallback onLeave;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = theme.extension<AppColors>();
    // Status reads from the theme's semantic roles, so it stays legible on
    // the warm light surface as well as the dark one. The neon *Accent
    // variants only ever worked on near-black.
    final (label, color) = switch (status) {
      LiveStatus.live => ('Live', app?.growth ?? scheme.primary),
      LiveStatus.connecting => ('Connecting…', scheme.tertiary),
      LiveStatus.error => ('Offline', scheme.error),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  casting == null
                      ? 'Pick something to cast'
                      : 'Casting · $casting',
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // The CONTROLLER's code — hand it to a screen to add it.
                    // Flexible + ellipsis so the longer 6-char code can't
                    // overflow the header Row on a narrow phone.
                    Flexible(
                      child: Text(
                        peers > 0
                            ? '$label · code $code · $peers '
                                  '${peers == 1 ? 'screen' : 'screens'}'
                            : '$label · your code $code — add a screen',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (peers > 0) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.tv, color: scheme.onSurfaceVariant, size: 14),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onStop,
            icon: Icon(Icons.stop_circle_outlined, color: scheme.error),
            label: Text('Stop', style: TextStyle(color: scheme.error)),
          ),
          TextButton.icon(
            onPressed: onLeave,
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
            // "Leave" MINIMIZES — the cast persists in castSessionProvider and
            // the chrome pill keeps showing the code on every screen. Only
            // "Stop" ends the session.
            label: Text(
              'Leave',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
