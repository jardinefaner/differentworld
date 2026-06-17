import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/live_session/cast_cockpit.dart';
import 'package:differentworld/features/live_session/cast_code.dart';
import 'package:differentworld/features/live_session/cast_immersive.dart';
import 'package:differentworld/features/live_session/cast_receiver.dart';
import 'package:differentworld/features/live_session/cast_session_controller.dart';
import 'package:differentworld/features/live_session/room_screen_setting.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/cast` — the app remote (docs/LIVE_SESSIONS.md "the cast model"). Make one
/// device the clean **Receiver** (the big screen) and drive it from another as
/// the **Caster** (this phone): pick what to present, switch it, control it —
/// all from the phone, while the screen shows only the clean output.
class CastScreen extends ConsumerStatefulWidget {
  const CastScreen({super.key, this.presentAsScreen = false});

  /// Open straight into receiver (room-screen) mode on the program channel —
  /// the launch auto-resume + the "make this the room screen" setup pass this.
  final bool presentAsScreen;

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
    final myCode = _myControllerCode();
    final followed = ref.read(roomScreenFollowsProvider).value;
    final snap = ref.read(castSessionProvider);
    if (widget.presentAsScreen && myCode != null) {
      // Setup just made this a screen → follow MY controller's code.
      _mode = _Mode.receive;
      _code = myCode;
      _enterImmersiveSoon();
    } else if (followed != null) {
      // Already a room screen → resume following its controller's code. Set
      // once; it just comes back up on the same controller.
      _mode = _Mode.receive;
      _code = followed;
      _enterImmersiveSoon();
    } else if (snap.active && snap.code != null) {
      // Resume a live cast: the chrome pill lands on the controls, not lobby.
      _mode = _Mode.cast;
      _code = snap.code!;
      _enterImmersiveSoon();
    }
    // else → lobby (the default _mode) to pick "cast" or "be a screen".
  }

  // Provider write off the build phase (AppShell watches castImmersive).
  void _enterImmersiveSoon() => unawaited(Future.microtask(() {
        if (mounted) _immersive.enter();
      }));

  /// MY controller code — the channel I broadcast on when I cast, and the one a
  /// screen signed into my account auto-follows. Null only with no member id.
  String? _myControllerCode() {
    final memberId = ref.read(viewerProvider).memberId;
    return memberId == null ? null : castCodeForController(memberId);
  }

  @override
  void dispose() {
    _immersive.exit();
    super.dispose();
  }

  /// Make this device a room screen that FOLLOWS [controllerCode] (persisted) +
  /// show the receiver. The "use this device as a screen" path passes my own
  /// controller code (same account, no typing); the manual entry passes another
  /// controller's code (the give-your-code-to-a-screen path).
  void _followController(String controllerCode) {
    unawaited(
      ref.read(roomScreenFollowsProvider.notifier).follow(controllerCode),
    );
    setState(() {
      _code = controllerCode;
      _mode = _Mode.receive;
    });
    _immersive.enter();
  }

  /// Cast AS the controller — broadcast on [code] (my own controller code) so
  /// every screen following it shows what I pick.
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
            child: SafeArea(
              child: _Lobby(
                myControllerCode: _myControllerCode(),
                onCast: _control,
                onFollow: _followController,
              ),
            ),
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
  const _Lobby({
    required this.onCast,
    required this.onFollow,
    this.myControllerCode,
  });

  /// Cast AS the controller — broadcast on my own controller code so my screens
  /// follow. The lobby's primary action.
  final ValueChanged<String> onCast;

  /// Make this device a screen following a controller code (my own, or one
  /// entered for a different controller).
  final ValueChanged<String> onFollow;

  /// My controller code (null only with no member id).
  final String? myControllerCode;

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

  void _follow() {
    final code = _codeCtrl.text.trim().toUpperCase();
    // Exact 4 — a short entry would follow an empty channel.
    if (code.length == 4) {
      widget.onFollow(code);
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
                'Cast',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your phone is the remote; your screens follow your code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 28),
              if (widget.myControllerCode case final code?) ...[
                // Everyday path: cast AS the controller. Every screen following
                // your code shows what you pick.
                _BigCard(
                  icon: Icons.cast,
                  title: 'Cast to your screens',
                  subtitle: 'Pick a game, world, or activity — it shows on '
                      'every screen following your code ($code).',
                  onTap: () => widget.onCast(code),
                ),
                const SizedBox(height: 14),
                _BigCard(
                  icon: Icons.tv,
                  title: 'Use this device as a screen',
                  subtitle: 'Make this TV or tablet follow you — set once, it '
                      'comes back up on its own.',
                  onTap: () => widget.onFollow(code),
                ),
                const SizedBox(height: 14),
              ],
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
                            'Be a screen for a controller',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Enter a controller's code — this device then follows them.",
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
                      onSubmitted: (_) => _follow(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w500,
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
                        onPressed: _follow,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(88, 56),
                        ),
                        child: const Text('Follow'),
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
