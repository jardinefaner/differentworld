import 'dart:async';

import 'package:differentworld/core/invites/invite_code.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/onboarding/create_space_screen.dart';
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

class _AutoMatchScaffold extends StatelessWidget {
  const _AutoMatchScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Looking for your invite…'),
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
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.waving_hand_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to Different World',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Let's get you into a program.",
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
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
                        'Create your own program — you become its director '
                        'and can invite your team.',
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
                ],
              ),
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
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
        title: const Text('Enter invite code'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.key_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Type the 6-character code',
                    style: theme.textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your director can find this in Settings → Team.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !submitting,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Za-z0-9 \-_]'),
                      ),
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: 'ABC-DEF',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 20),
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
      ),
    );
  }
}
