import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/action_words/conductor.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/world_cast_game.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The **Cockpit** — the phone as the app remote (docs/LIVE_SESSIONS.md "the
/// cast model"). The authority: it picks what to present (the launcher),
/// drives it (the controls), and switches it at will. Everything here stays on
/// the phone — only the chosen game + its state ride the wire to the Receiver.
class CastCockpit extends ConsumerStatefulWidget {
  const CastCockpit({required this.code, required this.onLeave, super.key});

  final String code;
  final VoidCallback onLeave;

  @override
  ConsumerState<CastCockpit> createState() => _CastCockpitState();
}

class _CastCockpitState extends ConsumerState<CastCockpit> {
  CastSession? _session;
  final _subs = <StreamSubscription<dynamic>>[];
  Map<String, dynamic> _meta = CastSession.idleState;
  LiveStatus _status = LiveStatus.connecting;
  int _peers = 0;
  // The "can't reach a screen → run solo" banner. Re-armed each time the
  // session (re)enters the error state so a transient blip that the teacher
  // dismissed reappears if the connection drops again.
  bool _errorBannerDismissed = false;
  // The launcher is the home; casting hides it, "Switch" brings it back. It's
  // phone-local — opening it never changes what the screen is showing.
  bool _showLauncher = true;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable()); // the remote shouldn't sleep mid-session
    final session = CastSession.cast(
      client: ref.read(supabaseProvider),
      code: widget.code,
    );
    _subs
      ..add(
        session.states.listen((v) {
          if (mounted) setState(() => _meta = v);
        }),
      )
      ..add(
        session.peers.listen((v) {
          if (mounted) setState(() => _peers = v);
        }),
      )
      ..add(
        session.status.listen((v) {
          if (!mounted) return;
          setState(() {
            // Re-arm the solo banner on each fresh transition INTO error.
            if (v == LiveStatus.error && _status != LiveStatus.error) {
              _errorBannerDismissed = false;
            }
            _status = v;
          });
        }),
      );
    _session = session;
  }

  @override
  void dispose() {
    unawaited(WakelockPlus.disable());
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_session?.dispose());
    super.dispose();
  }

  ContentSource _contentNow() =>
      ContentEngine(ref.read(bankedContentProvider).value ?? curatedSeeds);

  void _castGame(GameDefinition<dynamic> def) {
    _session?.cast(def, _contentNow());
    setState(() => _showLauncher = false);
  }

  /// Cast the live curriculum world — an explicit-seed presentable, not a
  /// content-bank game, so it goes through castStage (docs/WORLD.md).
  void _castWorld(CurriculumWorld world) {
    _session?.castStage(WorldCastGame.gameId, worldCastSeed(world));
    setState(() => _showLauncher = false);
  }

  /// Conduct any text — paste lyrics / a sentence, cast it, then tap a word
  /// to spotlight it on the screen (the Conductor).
  Future<void> _castConductor() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF14151D),
      builder: (_) => const _ConductSheet(),
    );
    if (text == null || text.trim().isEmpty) return;
    _session?.castStage(ConductorGame.gameId, conductorSeed(text));
    if (mounted) setState(() => _showLauncher = false);
  }

  void _send(GameIntent intent, [Map<String, dynamic> args = const {}]) {
    final id = CastSession.gameIdOf(_meta);
    final def = id == null ? null : gameById(id);
    // "Play again" re-casts with FRESH content (the pure reducer can't pull
    // new content); everything else reduces on the authority.
    if (intent == GameIntent.reset && def != null) {
      _session?.cast(def, _contentNow());
    } else {
      _session?.send(intent, args);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameId = CastSession.gameIdOf(_meta);
    final def = gameId == null ? null : gameById(gameId);
    // The live world is the one thing a stranded caster can still present
    // locally (the present screen runs without a Receiver). Null when the
    // journey isn't set up → the banner falls back to a "check the code" hint.
    final world = ref.watch(currentWorldProvider);

    return Column(
      children: [
        _CockpitHeader(
          status: _status,
          peers: _peers,
          code: widget.code,
          casting: def?.title,
          onLeave: widget.onLeave,
        ),
        // No second screen / lost the link? Don't strand the teacher driving a
        // dead cast — offer to show this week's world on just this device.
        if (_status == LiveStatus.error && !_errorBannerDismissed)
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
              onPick: _castGame,
              presentWorld: world,
              onPresentWorld: _castWorld,
              onConduct: _castConductor,
            ),
          )
        else ...[
          Expanded(
            key: const ValueKey('cockpit-driving'),
            child: _Driving(def: def, meta: _meta, send: _send),
          ),
          _SwitchBar(
            onSwitch: () => setState(() => _showLauncher = true),
            onStop: () {
              _session?.clearStage();
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
        color: Colors.redAccent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
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
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          if (canSolo) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onSolo,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0C0D14),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Show here'),
            ),
          ],
          IconButton(
            tooltip: 'Dismiss',
            icon: const Icon(Icons.close, color: Colors.white54, size: 20),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// The launcher — pick what to cast. The whole game deck, by vibe colour.
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
    return GridView.extent(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      maxCrossAxisExtent: 200,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
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
            color: const Color(0xFF2A6B7A),
            onTap: onConduct!,
          ),
        // Only content-bank games — roster/schedule-seeded ones (Now & Next,
        // Spotlight) would cast an empty stage (docs/LIVE_SESSIONS.md v1 scope).
        for (final def in liveGames.where((d) => d.seedsFromContentBank))
          _LauncherTile(def: def, onTap: () => onPick(def)),
      ],
    );
  }
}

/// A non-game launcher tile (the Conductor, future presentables).
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
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
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
            const Text(
              'Conduct',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Paste lyrics or type a sentence — one line per line. Tap a word '
              'on the screen to spotlight it.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 3,
              maxLines: 8,
              style: const TextStyle(color: Colors.white),
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Twinkle twinkle little star…',
                hintStyle: TextStyle(color: Colors.white30),
                border: OutlineInputBorder(),
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
    return Material(
      color: world.color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(world.emoji, style: const TextStyle(fontSize: 28)),
              const Spacer(),
              Text(
                'Week ${world.week}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                world.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Tap to cast',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LauncherTile extends StatelessWidget {
  const _LauncherTile({required this.def, required this.onTap});

  final GameDefinition<dynamic> def;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: def.vibe.accent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cast, color: Colors.white, size: 28),
              const Spacer(),
              Text(
                def.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Tap to cast',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Driving a cast game: the stage (what the room sees) + its controls.
class _Driving extends StatelessWidget {
  const _Driving({required this.def, required this.meta, required this.send});

  final GameDefinition<dynamic> def;
  final Map<String, dynamic> meta;
  final void Function(GameIntent, [Map<String, dynamic>]) send;

  @override
  Widget build(BuildContext context) {
    final wire = CastSession.gameStateOf(meta);
    final state = def.decode(wire);
    final custom = def.buildControls(context, state, send);
    return Column(
      children: [
        Expanded(
          child: ColoredBox(
            color: def.vibe.surface,
            child: def.buildStage(context, state),
          ),
        ),
        if (custom != null)
          _Bar(child: custom)
        else
          _CastControls(def: def, wire: wire, onIntent: send),
      ],
    );
  }
}

/// The standard control bar, built from the game's *active* intents — same
/// vocabulary the single-device + live bars use (Back · Reveal · +1 · Next ·
/// Again), so it fits any game shape.
class _CastControls extends StatelessWidget {
  const _CastControls({
    required this.def,
    required this.wire,
    required this.onIntent,
  });

  final GameDefinition<dynamic> def;
  final Map<String, dynamic> wire;
  final void Function(GameIntent, [Map<String, dynamic>]) onIntent;

  @override
  Widget build(BuildContext context) {
    final active = def.activeIntents(def.decode(wire));
    final index = (wire['i'] as num?)?.toInt() ?? 0;
    final total = (wire['n'] as num?)?.toInt() ?? 0;
    final done = wire['d'] == true;
    final revealed = wire['r'] == true;

    final buttons = <Widget>[
      if (active.contains(GameIntent.back))
        IconButton.filledTonal(
          onPressed: () => onIntent(GameIntent.back),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
        ),
      if (active.contains(GameIntent.reveal))
        FilledButton.tonalIcon(
          onPressed: () => onIntent(GameIntent.reveal),
          icon: Icon(revealed ? Icons.visibility_off : Icons.lightbulb_outline),
          label: Text(def.revealLabel(revealed: revealed)),
        ),
      if (active.contains(GameIntent.tally))
        FilledButton.tonalIcon(
          onPressed: () => onIntent(GameIntent.tally),
          icon: const Icon(Icons.add),
          label: const Text('+1'),
        ),
      if (active.contains(GameIntent.next))
        FilledButton.icon(
          onPressed: () => onIntent(GameIntent.next),
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Next'),
        ),
      if (active.contains(GameIntent.reset))
        FilledButton.icon(
          onPressed: () => onIntent(GameIntent.reset),
          icon: const Icon(Icons.replay),
          label: const Text('Again'),
        ),
    ];

    return _Bar(
      child: Row(
        children: [
          if (wire['n'] != null)
            Text(
              done ? 'Done' : '${index + 1} / $total',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          const Spacer(),
          for (final b in buttons) ...[b, const SizedBox(width: 8)],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: child,
      ),
    );
  }
}

class _SwitchBar extends StatelessWidget {
  const _SwitchBar({required this.onSwitch, required this.onStop});

  final VoidCallback onSwitch;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.04),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
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
  });

  final LiveStatus status;
  final int peers;
  final String code;
  final String? casting;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LiveStatus.live => ('Live', Colors.greenAccent),
      LiveStatus.connecting => ('Connecting…', Colors.amberAccent),
      LiveStatus.error => ('Offline', Colors.redAccent),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
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
                    Text(
                      '$label · screen $code',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    if (peers > 1) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.tv, color: Colors.white38, size: 14),
                    ],
                  ],
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onLeave,
            icon: const Icon(Icons.close, color: Colors.white70),
            // "Leave" not "End" — this returns the phone to the lobby; the
            // screen stays on (idle) until it's closed there.
            label: const Text('Leave', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
