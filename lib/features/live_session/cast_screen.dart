import 'dart:async';

import 'package:differentworld/features/live_session/cast_cockpit.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/features/live_session/cast_receiver.dart';
import 'package:differentworld/features/live_session/cast_session_controller.dart';
import 'package:differentworld/features/live_session/live_game_screen.dart'
    show generateSessionCode;
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/cast` — the app remote (docs/LIVE_SESSIONS.md "the cast model"). Make one
/// device the clean **Receiver** (the big screen) and drive it from another as
/// the **Caster** (this phone): pick what to present, switch it, control it —
/// all from the phone, while the screen shows only the clean output.
class CastScreen extends ConsumerStatefulWidget {
  const CastScreen({super.key});

  @override
  ConsumerState<CastScreen> createState() => _CastScreenState();
}

enum _Mode { lobby, receive, cast }

class _CastScreenState extends ConsumerState<CastScreen> {
  _Mode _mode = _Mode.lobby;
  String _code = '';
  // Cached so dispose() can reset it without touching ref. Driving the
  // presentation surfaces immersive is what hides AppShell's chrome (the top
  // pills + the omnibox bar) so they can't paint over the cockpit/stage.
  late final CastImmersive _immersive;

  @override
  void initState() {
    super.initState();
    _immersive = ref.read(castImmersiveProvider.notifier);
    // Resume a live cast: if a session is already up (the persistent anchor),
    // open straight into the cockpit on its code — tapping the chrome pill
    // from anywhere lands on the controls, not the lobby.
    final snap = ref.read(castSessionProvider);
    if (snap.active && snap.code != null) {
      _mode = _Mode.cast;
      _code = snap.code!;
      // Provider write off the build phase (AppShell watches castImmersive).
      unawaited(Future.microtask(() {
        if (mounted) _immersive.enter();
      }));
    }
  }

  @override
  void dispose() {
    _immersive.exit();
    super.dispose();
  }

  void _presentHere() {
    setState(() {
      _code = generateSessionCode();
      _mode = _Mode.receive;
    });
    _immersive.enter(); // a callback, not build — safe to write the provider
  }

  void _control(String code) {
    setState(() {
      _code = code;
      _mode = _Mode.cast;
    });
    _immersive.enter();
  }

  void _toLobby() {
    setState(() => _mode = _Mode.lobby);
    _immersive.exit();
  }

  @override
  Widget build(BuildContext context) {
    // Back from a live role returns to the lobby (not out of /cast).
    return PopScope(
      canPop: _mode == _Mode.lobby,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toLobby();
      },
      child: switch (_mode) {
        _Mode.lobby => EdgeScaffold(
          body: ColoredBox(
            color: const Color(0xFF0C0D14),
            child: SafeArea(child: _Lobby(onPresent: _presentHere, onJoin: _control)),
          ),
        ),
        // The Receiver owns its own clean Scaffold — no chrome over the stage.
        _Mode.receive => CastReceiver(
          key: ValueKey('rx-$_code'),
          code: _code,
          onExit: _toLobby,
        ),
        _Mode.cast => Scaffold(
          backgroundColor: const Color(0xFF0C0D14),
          body: SafeArea(
            child: CastCockpit(
              key: ValueKey('cast-$_code'),
              code: _code,
              onLeave: _toLobby,
            ),
          ),
        ),
      },
    );
  }
}

class _Lobby extends StatefulWidget {
  const _Lobby({required this.onPresent, required this.onJoin});

  final VoidCallback onPresent;
  final ValueChanged<String> onJoin;

  @override
  State<_Lobby> createState() => _LobbyState();
}

class _LobbyState extends State<_Lobby> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  String? _error;

  void _join() {
    final code = _codeCtrl.text.trim().toUpperCase();
    // Exact 4 — a short entry would join an empty channel (and a loose match
    // raises the odds of two phones landing on the same code → two authorities).
    if (code.length == 4) {
      widget.onJoin(code);
    } else {
      setState(() => _error = 'The code is exactly 4 characters.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cast to a screen',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'One device shows it big; this phone is the remote.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 28),
              _BigCard(
                icon: Icons.cast,
                title: 'Use this device as the screen',
                subtitle: 'Open this on a TV or laptop — it shows a join code '
                    'for your phone.',
                onTap: widget.onPresent,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.smartphone, color: Colors.tealAccent, size: 32),
                        SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Control a screen',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter the code on the screen — then cast + control from here.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.go,
                      maxLength: 4,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _join(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w800,
                      ),
                      decoration: InputDecoration(
                        hintText: 'CODE',
                        hintStyle: const TextStyle(
                          color: Colors.white24,
                          letterSpacing: 6,
                        ),
                        border: const OutlineInputBorder(),
                        counterText: '',
                        errorText: _error,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _join,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(88, 56),
                        ),
                        child: const Text('Control'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  const _BigCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(icon, color: Colors.tealAccent, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
