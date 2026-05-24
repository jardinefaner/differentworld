import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/invites/invite_code.dart';
import 'package:differentworld/features/invites/deep_link_listener.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/onboarding/create_space_screen.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// First-time landing for a signed-in user without a space.
///
/// Flow (see CLAUDE.md "Onboarding"):
///   1. On mount, try email auto-match: rpc accept_invite(null). If the
///      caller's auth.users.email matches an invite, the backend updates
///      their member row and we never render anything past the spinner —
///      the currentMember stream replaces this screen with the signed-in
///      home.
///   2. If no match (`NoMatchingInviteException`), show two options:
///      "Enter invite code" and "Start a new program".
///   3. Entering a code calls accept_invite(code). Success → stream
///      swaps us out. Failure → inline error, code field stays.
class JoinOrCreateScreen extends ConsumerStatefulWidget {
  const JoinOrCreateScreen({super.key});

  @override
  ConsumerState<JoinOrCreateScreen> createState() =>
      _JoinOrCreateScreenState();
}

enum _Stage {
  /// Email auto-match is in flight on first mount.
  autoMatching,

  /// No matching invite — show the two-paths picker.
  choosing,

  /// User picked "Enter code".
  enteringCode,

  /// Redemption in flight.
  redeeming,
}

class _JoinOrCreateScreenState extends ConsumerState<JoinOrCreateScreen> {
  final _codeController = TextEditingController();
  _Stage _stage = _Stage.autoMatching;
  String? _error;

  Timer? _autoMatchTimeout;

  @override
  void initState() {
    super.initState();
    // Fire the auto-match attempt on next frame so the build cycle
    // finishes first; if it succeeds the currentMember stream rebuilds
    // the router and disposes us before we mount anything else.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAutoMatch());

    // Safety net: if the RPC succeeds but the member stream takes too
    // long to deliver the new space_id (slow PowerSync round-trip,
    // server hiccup), don't leave the user staring at the spinner.
    _autoMatchTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_stage == _Stage.autoMatching) {
        setState(() => _stage = _Stage.choosing);
      }
    });
  }

  @override
  void dispose() {
    _autoMatchTimeout?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _tryAutoMatch() async {
    // Honor a code from an inbound deep link first — if a user just
    // scanned a QR or tapped a shared link, that takes precedence over
    // the email auto-match path.
    final pending = ref.read(pendingInviteCodeProvider);
    if (pending != null && pending.isNotEmpty) {
      // Clear the pending code now so a transient failure doesn't trap
      // the user in a redeem loop.
      ref.read(pendingInviteCodeProvider.notifier).clear();
      _autoMatchTimeout?.cancel();
      try {
        await ref.read(inviteActionsProvider).redeem(code: pending);
        // Stream swap-out as usual.
        return;
      } on NoMatchingInviteException {
        if (!mounted) return;
        setState(() {
          _stage = _Stage.enteringCode;
          _codeController.text = pending;
          _error = "We couldn't find that invite. Double-check the code "
              'with your director.';
        });
        return;
      } on Exception catch (e, st) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: e, stack: st, library: 'invites'),
        );
        if (!mounted) return;
        setState(() {
          _stage = _Stage.enteringCode;
          _codeController.text = pending;
          _error = 'Could not redeem that invite. Please try again.';
        });
        return;
      }
    }

    try {
      await ref.read(inviteActionsProvider).redeem();
      // On success the currentMember stream will pick up the new
      // space_id and swap this screen out. Until then, stay on the
      // spinner — don't change state here.
    } on NoMatchingInviteException {
      if (!mounted) return;
      setState(() => _stage = _Stage.choosing);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'invites'),
      );
      if (!mounted) return;
      setState(() {
        _stage = _Stage.choosing;
        _error = 'Could not check for your invite. You can still join '
            'with a code or start a new program.';
      });
    }
  }

  Future<void> _redeemCode() async {
    final raw = _codeController.text;
    final code = InviteCode.normalize(raw);
    if (code.isEmpty) {
      setState(() => _error = 'Enter the code your director gave you.');
      return;
    }

    setState(() {
      _stage = _Stage.redeeming;
      _error = null;
    });

    try {
      await ref.read(inviteActionsProvider).redeem(code: code);
      // Stream will swap us out on success.
    } on NoMatchingInviteException {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.enteringCode;
        _error = "We couldn't find that invite. Double-check the code "
            'with your director.';
      });
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'invites'),
      );
      if (!mounted) return;
      setState(() {
        _stage = _Stage.enteringCode;
        _error = 'Could not redeem that invite. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Warm deep-link arrivals: if a new code lands while the user is
    // still on the choosing/code-entry screens, snap back to the
    // auto-match path so it consumes the code.
    ref.listen<String?>(pendingInviteCodeProvider, (prev, next) {
      if (next == null || next.isEmpty) return;
      if (_stage == _Stage.redeeming || _stage == _Stage.autoMatching) return;
      setState(() {
        _stage = _Stage.autoMatching;
        _error = null;
      });
      unawaited(_tryAutoMatch());
    });

    return switch (_stage) {
      _Stage.autoMatching => const _AutoMatchScaffold(),
      _Stage.choosing => _ChoosingScaffold(
          onEnterCode: () => setState(() {
            _stage = _Stage.enteringCode;
            _error = null;
          }),
          warning: _error,
        ),
      _Stage.enteringCode => _CodeEntryScaffold(
          controller: _codeController,
          error: _error,
          submitting: false,
          onSubmit: _redeemCode,
          onBack: () => setState(() {
            _stage = _Stage.choosing;
            _error = null;
            _codeController.clear();
          }),
        ),
      _Stage.redeeming => _CodeEntryScaffold(
          controller: _codeController,
          submitting: true,
          onSubmit: _redeemCode,
        ),
    };
  }
}

class _AutoMatchScaffold extends StatefulWidget {
  const _AutoMatchScaffold();

  @override
  State<_AutoMatchScaffold> createState() => _AutoMatchScaffoldState();
}

class _AutoMatchScaffoldState extends State<_AutoMatchScaffold> {
  late final Stopwatch _watch;
  Timer? _tick;
  int _elapsedSec = 0;

  @override
  void initState() {
    super.initState();
    _watch = Stopwatch()..start();
    // Periodic UI tick to upgrade the helper copy after 3s ("might be
    // slow offline") and not surprise the user when nothing happens.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSec = _watch.elapsed.inSeconds);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final helper = _elapsedSec >= 3
        ? "This can take a moment offline. We'll keep looking…"
        : '';
    return EdgeScaffold(
      showBack: false,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Looking for your invite…'),
            const SizedBox(height: 8),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: helper.isEmpty ? 0 : 1,
              child: Text(
                helper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoosingScaffold extends StatelessWidget {
  const _ChoosingScaffold({required this.onEnterCode, this.warning});

  final VoidCallback onEnterCode;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EdgeScaffold(
      showBack: false,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ContentHeader(
                  title: 'Welcome to Different World',
                  subtitle: "Let's get you into a program.",
                ),
                Icon(
                  Icons.waving_hand_outlined,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                  if (warning != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      warning!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 32),
                  _PrimaryCard(
                    icon: Icons.key_outlined,
                    title: 'I have an invite code',
                    subtitle:
                        'Your director gave you a 6-character code or a '
                        'QR to scan.',
                    onTap: onEnterCode,
                  ),
                  const SizedBox(height: 12),
                  _PrimaryCard(
                    icon: Icons.add_business_outlined,
                    title: 'Start a new program',
                    subtitle:
                        'About 3 questions, takes a minute. You become its '
                        'director and can invite your team.',
                    onTap: () {
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CreateSpaceScreen(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  // Escape hatch: signed in with the wrong Google
                  // account? Sign out and start over without quitting
                  // the app.
                  Consumer(builder: (context, ref, _) {
                    return Center(
                      child: TextButton(
                        onPressed: () async {
                          await ref
                              .read(authActionsProvider)
                              .signOut();
                        },
                        child: const Text(
                          'Use a different Google account',
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
    );
  }
}

class _PrimaryCard extends StatelessWidget {
  const _PrimaryCard({
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
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CodeEntryScaffold extends StatelessWidget {
  const _CodeEntryScaffold({
    required this.controller,
    required this.onSubmit,
    required this.submitting,
    this.error,
    this.onBack,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool submitting;
  final String? error;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // showBack only renders the floating back pill if `onBack` is set —
    // when no back handler is provided (deep-link landed straight on
    // code-entry) the floating chrome stays clean. Tap routes through
    // the standard EdgeScaffold back machinery.
    return EdgeScaffold(
      showBack: onBack != null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ContentHeader(
                  title: 'Enter invite code',
                  subtitle: 'Type the 6-character code your director gave you.',
                ),
                Icon(
                  Icons.key_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 24),
                  // 6-cell PIN-style input. Each cell is a Material 3
                  // outlined box; typing into any one auto-advances to
                  // the next. The hidden underlying TextField holds
                  // the canonical value the rest of the screen reads.
                  _PinInput(
                    controller: controller,
                    enabled: !submitting,
                    onCompleted: onSubmit,
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: submitting ? null : onSubmit,
                    icon: submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Join program'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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

/// 6-cell PIN-style input. Uses a single offstage [TextField] (so
/// platform paste / autofill / soft-keyboard all behave normally) and
/// six visual cells. The visible cells reflect the underlying value
/// character by character and the cursor sits on the next empty cell.
class _PinInput extends StatefulWidget {
  const _PinInput({
    required this.controller,
    required this.enabled,
    required this.onCompleted,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onCompleted;

  @override
  State<_PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<_PinInput> {
  final FocusNode _focus = FocusNode();
  // Whether the controller already has 6 characters — drives the
  // "auto-submit on completion" behavior.
  bool _wasComplete = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    final v = InviteCode.normalize(widget.controller.text);
    // Reflect the normalized value back so paste of "abc-def" lands as
    // "ABCDEF" in both the underlying value and the visible cells.
    if (v != widget.controller.text) {
      widget.controller.value = widget.controller.value.copyWith(
        text: v,
        selection: TextSelection.collapsed(offset: v.length),
      );
    }
    final complete = v.length >= 6;
    if (complete && !_wasComplete) {
      _wasComplete = true;
      // Slight delay so the user sees the last cell fill before we
      // navigate. Submitting on completion is a UX accelerator —
      // no need to also tap the button.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onCompleted();
      });
    } else if (!complete) {
      _wasComplete = false;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = widget.controller.text;
    return GestureDetector(
      onTap: () {
        if (widget.enabled) _focus.requestFocus();
      },
      child: Stack(
        children: [
          // Offstage real input — handles keyboard, paste, autofill.
          // We position it 1×1 so it remains hit-testable for IME.
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[A-Za-z0-9 \-_]'),
                ),
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(color: Colors.transparent),
              cursorColor: Colors.transparent,
              onSubmitted: (_) => widget.onCompleted(),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 6; i++)
                _PinCell(
                  char: i < value.length ? value[i] : null,
                  active: widget.enabled && i == value.length && _focus.hasFocus,
                  scheme: scheme,
                  textStyle: theme.textTheme.headlineMedium,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PinCell extends StatelessWidget {
  const _PinCell({
    required this.char,
    required this.active,
    required this.scheme,
    required this.textStyle,
  });

  final String? char;
  final bool active;
  final ColorScheme scheme;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? scheme.primary
        : (char != null ? scheme.outline : scheme.outlineVariant);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 44,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: active ? 2 : 1),
        color: scheme.surface,
      ),
      child: Center(
        child: Text(
          char ?? '',
          style: textStyle?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
