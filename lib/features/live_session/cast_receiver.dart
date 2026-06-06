import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The **Receiver** — the big screen as a dumb, clean display
/// (docs/LIVE_SESSIONS.md "the cast model"). Joins as a follower, shows the
/// join code while idle, and once the phone casts something renders ONLY the
/// game's clean stage — no header, no controls, no launcher. The screen never
/// sees what you do on the phone.
class CastReceiver extends ConsumerStatefulWidget {
  const CastReceiver({required this.code, super.key});

  final String code;

  @override
  ConsumerState<CastReceiver> createState() => _CastReceiverState();
}

class _CastReceiverState extends ConsumerState<CastReceiver> {
  CastSession? _session;
  final _subs = <StreamSubscription<dynamic>>[];
  Map<String, dynamic> _meta = CastSession.idleState;
  LiveStatus _status = LiveStatus.connecting;

  @override
  void initState() {
    super.initState();
    final session = CastSession.receive(
      client: ref.read(supabaseProvider),
      code: widget.code,
    );
    _subs
      ..add(session.states.listen((v) {
        if (mounted) setState(() => _meta = v);
      }))
      ..add(session.status.listen((v) {
        if (mounted) setState(() => _status = v);
      }));
    _session = session;
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_session?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameId = CastSession.gameIdOf(_meta);
    final def = gameId == null ? null : gameById(gameId);

    final Widget body;
    if (gameId == null) {
      body = _IdleCard(code: widget.code, status: _status);
    } else if (def == null) {
      // The phone cast a game this build doesn't know (a newer app).
      body = const _IdleMessage(
        icon: Icons.system_update_alt,
        text: 'This session needs a newer version of the app.',
      );
    } else {
      // The clean stage — full-bleed, nothing else.
      body = ColoredBox(
        color: def.vibe.surface,
        child: def.buildStage(context, def.decode(CastSession.gameStateOf(_meta))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D14),
      body: body,
    );
  }
}

/// The "waiting for your phone" screen — the only time the Receiver shows
/// chrome. Big, readable join code; goes fully clean the moment you cast.
class _IdleCard extends StatelessWidget {
  const _IdleCard({required this.code, required this.status});

  final String code;
  final LiveStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      LiveStatus.live => ('Ready — cast from your phone', Colors.greenAccent),
      LiveStatus.connecting => ('Connecting…', Colors.amberAccent),
      LiveStatus.error => ('Offline', Colors.redAccent),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cast, color: Colors.white24, size: 56),
          const SizedBox(height: 24),
          const Text(
            'JOIN CODE',
            style: TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            code,
            style: const TextStyle(
              color: Colors.tealAccent,
              fontWeight: FontWeight.w900,
              fontSize: 88,
              letterSpacing: 12,
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'On your phone: Present → Cast → enter this code',
            style: TextStyle(color: Colors.white38, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _IdleMessage extends StatelessWidget {
  const _IdleMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white24, size: 56),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 18),
            ),
          ),
        ],
      ),
    );
  }
}
