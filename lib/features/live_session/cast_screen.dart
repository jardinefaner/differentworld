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
  const CastScreen({
    super.key,
    this.presentAsScreen = false,
    this.castOnConnect,
  });

  /// A game id to put on the screen the moment a cast is live — the intent
  /// carried from wherever the cast was asked for (`/cast?cast=<id>`).
  final String? castOnConnect;

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
    } else if (widget.castOnConnect != null && myCode != null) {
      // Asked to cast something specific with no screen connected yet. Go
      // straight to the cockpit on my own code: it shows the join code for a
      // TV and casts the moment one joins, so the answer to "put this on the
      // screen" is never a menu about casting.
      _mode = _Mode.cast;
      _code = myCode;
      _enterImmersiveSoon();
    }
    // else → lobby (the default _mode) to pick "cast" or "be a screen".
  }

  // Provider write off the build phase (AppShell watches castImmersive).
  void _enterImmersiveSoon() => unawaited(
    Future.microtask(() {
      if (mounted) _immersive.enter();
    }),
  );

  /// MY controller code — the channel I broadcast on when I cast, and the one a
  /// screen signed into my account auto-follows. Null without a member/space.
  String? _myControllerCode() {
    final viewer = ref.read(viewerProvider);
    final memberId = viewer.memberId;
    final spaceId = viewer.spaceId;
    if (memberId == null || spaceId == null) return null;
    return castCodeForController(memberId: memberId, spaceId: spaceId);
  }

  @override
  void dispose() {
    // Deferred — see CastImmersive. A synchronous write here throws when the
    // screen is disposed during a build/finalize pass.
    final immersive = _immersive;
    unawaited(Future.microtask(immersive.exit));
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
      // Leaving the COCKPIT leaves /cast entirely, back to wherever you came
      // from — the cast keeps running (it lives above the screen, and the
      // chrome pill still shows it). Sending a caster to the lobby instead
      // asked "which device is this one?" of someone actively casting from
      // this one, which is not a question, it is a contradiction.
      //
      // Receiver mode still falls back to the lobby: this device IS the
      // screen, so backing out is a real mode change and the lobby is where
      // that decision is made.
      canPop: _mode != _Mode.receive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toLobby();
      },
      child: switch (_mode) {
        _Mode.lobby => EdgeScaffold(
          body: ColoredBox(
            color: Theme.of(context).colorScheme.surface,
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
          // The cockpit is the phone in your hand — a REMOTE, not a stage.
          // This used to be hardcoded near-black with a comment calling it
          // "a projection stage (the TV)", which is simply not what it is:
          // the Receiver is the TV, and the cockpit's own doc says everything
          // in it stays on the phone. The effect was that tapping "This is my
          // remote" left a warm cream app and landed in a black one.
          body: SafeArea(
            child: CastCockpit(
              key: ValueKey('cast-$_code'),
              code: _code,
              castOnConnect: widget.castOnConnect,
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

/// The lobby answers ONE question — **which device am I holding?**
///
/// That is the only branch here, and the old lobby never asked it. It showed
/// "Cast to your screens" and "Be a screen" as two equal cards, which reads as
/// a choice between two things to DO when it is really a choice between two
/// devices to BE: the phone in your hand wants the first, the TV across the
/// room wants the second, and a staffer holding a phone has no reason to know
/// the second card is not addressed to them.
///
/// Three smaller repairs come with the framing:
///
/// * **The code stopped being trivia.** It appeared three times in three
///   meanings — as a parenthetical in one subtitle, inside a button label, and
///   as the thing to type into a field. Here it is stated once, where it is
///   useful: on the remote, as what your screens follow.
/// * **The setup order is on screen.** Nothing said the TV has to be told
///   first. Now the remote path carries the one instruction the phone-holder
///   needs — and it is short, because signing the TV into the same account
///   means there is no code to type at all.
/// * **The code field went away by default.** Following SOMEONE ELSE'S
///   controller is the rare case (a second staffer's screens, a shared room),
///   so it is behind a disclosure instead of a text field sitting on a screen
///   whose job is a binary choice.
class _LobbyState extends State<_Lobby> {
  final _codeCtrl = TextEditingController();
  bool _showOther = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _follow() {
    final code = _codeCtrl.text.trim().toUpperCase();
    // Exact 6 — a short entry would follow an empty channel.
    if (code.length == 6) {
      widget.onFollow(code);
    } else {
      setState(() => _error = 'The code is exactly 6 characters.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final myCode = widget.myControllerCode;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cast to a screen',
                key: const ValueKey('cast-lobby-title'),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Which device is this one?',
                key: const ValueKey('cast-lobby-sub'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              if (myCode != null) ...[
                _DeviceCard(
                  key: const ValueKey('cast-remote'),
                  icon: Icons.smartphone,
                  title: 'This is my remote',
                  subtitle:
                      'Pick what the room sees. Screens following $myCode '
                      'show it.',
                  primary: true,
                  onTap: () => widget.onCast(myCode),
                ),
                const SizedBox(height: 12),
              ],
              _DeviceCard(
                key: const ValueKey('cast-be-a-screen'),
                icon: Icons.tv,
                title: 'This is the screen',
                subtitle: myCode == null
                    ? 'Show what a remote picks. Enter its code below.'
                    : 'For the TV or a spare tablet — it shows what your '
                          'remote picks.',
                primary: false,
                onTap: myCode == null ? null : () => widget.onFollow(myCode),
              ),
              const SizedBox(height: 18),
              // The instruction the phone-holder actually needs, and the one
              // the old lobby left them to guess: the TV has to be told first.
              // Kept to one sentence because same-account is genuinely this
              // simple — no code changes hands.
              if (myCode != null)
                Text(
                  key: const ValueKey('cast-setup-hint'),
                  'Setting up the TV? Open Different World on it, tap Cast, '
                  'then “This is the screen”. Signed into the same account, '
                  "there's no code to type.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              const SizedBox(height: 6),
              // Rare path, so it stays folded away: following a DIFFERENT
              // controller (another staffer's screens, a shared room).
              if (myCode != null)
                Align(
                  key: const ValueKey('cast-other-toggle'),
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => setState(() => _showOther = !_showOther),
                    child: Text(
                      _showOther
                          ? 'Never mind'
                          : "Following someone else's screens?",
                    ),
                  ),
                ),
              if (_showOther || myCode == null) ...[
                const SizedBox(height: 4),
                _CodeEntry(
                  key: const ValueKey('cast-code-entry'),
                  codeCtrl: _codeCtrl,
                  error: _error,
                  onSubmit: _follow,
                  onClearError: () {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the two devices this could be. Same shape for both so the choice
/// reads as "which one", not "which is the real button" — only the accent
/// edge separates the everyday path from the setup one.
class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final edge = primary ? scheme.primary : scheme.outlineVariant;
    // A card with no action must not look like one with an action. This is the
    // no-controller-code case, where "this is the screen" needs a code typed
    // in below before it means anything.
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: scheme.surfaceContainerHighest,
        // Rounded on the right only — the left edge IS the accent (BRAND.md
        // law 1), the same shape ActivityPrompt uses.
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: edge, width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 18, 18, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: scheme.primary, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Type a controller's code to follow it. Only on screen when it is the
/// actual task — a device with no controller code of its own, or the folded-
/// open "someone else's screens" path.
class _CodeEntry extends StatelessWidget {
  const _CodeEntry({
    required this.codeCtrl,
    required this.error,
    required this.onSubmit,
    required this.onClearError,
    super.key,
  });

  final TextEditingController codeCtrl;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onClearError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: codeCtrl,
          // Revealed on purpose — the user just asked for it, so the keyboard
          // should already be up rather than costing a second tap.
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.go,
          maxLength: 6,
          onChanged: (_) => onClearError(),
          onSubmitted: (_) => onSubmit(),
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 6),
          decoration: InputDecoration(
            hintText: 'Code',
            hintStyle: TextStyle(
              color: scheme.onSurfaceVariant,
              letterSpacing: 6,
            ),
            border: const OutlineInputBorder(),
            counterText: '',
            errorText: error,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(minimumSize: const Size(88, 56)),
            child: const Text('Follow'),
          ),
        ),
      ],
    );
  }
}
