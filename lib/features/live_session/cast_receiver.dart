import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:differentworld/features/live_session/live_session.dart';
import 'package:differentworld/shared/platform/fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// The **Receiver** — the big screen as a dumb, clean display
/// (docs/LIVE_SESSIONS.md "the cast model"). Joins as a follower, shows the
/// join code while idle, and once the phone casts something renders ONLY the
/// game's clean stage — no header, no controls, no launcher. The screen never
/// sees what you do on the phone.
class CastReceiver extends ConsumerStatefulWidget {
  const CastReceiver({required this.code, required this.onExit, super.key});

  final String code;

  /// Return to the cast lobby — the Receiver's full exit (the screen has no
  /// nav chrome). Surfaced in the tap-to-reveal controls + the disconnect card.
  final VoidCallback onExit;

  @override
  ConsumerState<CastReceiver> createState() => _CastReceiverState();
}

class _CastReceiverState extends ConsumerState<CastReceiver> {
  CastSession? _session;
  final _subs = <StreamSubscription<dynamic>>[];
  Map<String, dynamic> _meta = CastSession.idleState;
  LiveStatus _status = LiveStatus.connecting;
  // Fullscreen (OS bars hidden) is the default; a toggle in the revealed
  // controls drops to a windowed view + re-enters. The app chrome stays gone
  // either way (castImmersiveProvider) — this is just the OS bars.
  bool _fullscreen = true;
  // The controls (code · fullscreen · leave) auto-hide so the stage stays
  // clean; a tap anywhere on the screen brings them back.
  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    unawaited(WakelockPlus.enable()); // a presentation screen must not sleep
    unawaited(_applyFullscreen());
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
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    unawaited(WakelockPlus.disable());
    // Restore the app's default (EdgeScaffold draws under the bars).
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    unawaited(_session?.dispose());
    super.dispose();
  }

  Future<void> _applyFullscreen() => SystemChrome.setEnabledSystemUIMode(
        _fullscreen ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _revealControls() {
    if (!_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleFullscreen() {
    setState(() => _fullscreen = !_fullscreen);
    unawaited(_applyFullscreen());
    // On web, immersiveSticky is a no-op — drive the real browser Fullscreen
    // API too (no-op on native) so a cast receiver in a desktop/TV browser
    // actually fills the screen.
    unawaited(toggleWebFullscreen());
    _revealControls();
  }

  @override
  Widget build(BuildContext context) {
    final gameId = CastSession.gameIdOf(_meta);
    final def = gameId == null ? null : gameById(gameId);
    // Casting, but the authority (phone) dropped — don't strand the room on a
    // frozen frame with no way out.
    final disconnected = _status == LiveStatus.error && gameId != null;

    final Widget body;
    if (gameId == null) {
      body = SafeArea(child: _IdleCard(code: widget.code, status: _status));
    } else if (def == null) {
      // The phone cast a game this build doesn't know (a newer app).
      body = const SafeArea(
        child: _IdleMessage(
          icon: Icons.system_update_alt,
          text: 'This session needs a newer version of the app.',
        ),
      );
    } else {
      // The clean stage — full-bleed, nothing else (no SafeArea by design).
      body = ColoredBox(
        color: def.vibe.surface,
        child: def.buildStage(context, def.decode(CastSession.gameStateOf(_meta))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C0D14),
      body: Stack(
        children: [
          // Tap anywhere to bring the controls back (buildStage has no
          // interactive elements, so this never steals a real tap).
          Positioned.fill(
            key: const ValueKey('cast-receiver-body'),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _revealControls,
              child: body,
            ),
          ),
          if (disconnected)
            Positioned.fill(
              key: const ValueKey('cast-receiver-disconnected'),
              child: _DisconnectedCard(onExit: widget.onExit),
            ),
          // Auto-hiding controls: join code (while casting) · fullscreen
          // toggle · leave. Hidden during the disconnect card (it has its own).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _Fade(
              visible: _controlsVisible && !disconnected,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      if (gameId != null) _CodeChip(code: widget.code),
                      const Spacer(),
                      IconButton(
                        tooltip: _fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                        onPressed: _toggleFullscreen,
                        icon: Icon(
                          _fullscreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          color: Colors.white70,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Leave',
                        onPressed: widget.onExit,
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + ignore-pointer wrapper for the auto-hiding controls.
class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: visible ? 1 : 0,
        child: child,
      ),
    );
  }
}

/// The join code, shown in the revealed controls so a late phone can still
/// join while something's already cast.
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CODE  ',
            style: TextStyle(
              color: Colors.white54,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          Text(
            code,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown over the frozen stage when the controlling phone disconnects — a
/// visible recovery path instead of a silent freeze.
class _DisconnectedCard extends StatelessWidget {
  const _DisconnectedCard({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Phone disconnected',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reconnect from the phone, or return to the lobby.',
              style: TextStyle(color: Colors.white60, fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onExit,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Return to lobby'),
            ),
          ],
        ),
      ),
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
            'On your phone: Present → Cast to a screen → Control',
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
