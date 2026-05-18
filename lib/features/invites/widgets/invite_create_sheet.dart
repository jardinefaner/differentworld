import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/invites/widgets/invite_share_sheet.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Director's "Invite teammate" sheet. Asks for role + optional email +
/// expiration, mints a code, then morphs into the share sheet showing
/// the code + QR + copy/share affordances.
class InviteCreateSheet extends ConsumerStatefulWidget {
  const InviteCreateSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const InviteCreateSheet(),
    );
  }

  @override
  ConsumerState<InviteCreateSheet> createState() => _InviteCreateSheetState();
}

class _InviteCreateSheetState extends ConsumerState<InviteCreateSheet> {
  final _emailController = TextEditingController();

  String _role = 'teacher';
  InviteExpiry _expiry = InviteExpiry.sevenDays;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isDirty() {
    // The defaults (teacher / 7 days / no email) are the rest state.
    // Anything off those = dirty.
    return _role != 'teacher' ||
        _expiry != InviteExpiry.sevenDays ||
        _emailController.text.trim().isNotEmpty;
  }

  Future<void> _create() async {
    if (_saving) return;
    final me = ref.read(currentMemberProvider).value;
    final spaceId = me?.spaceId;
    if (spaceId == null) {
      setState(() => _error = 'No program selected.');
      return;
    }
    if (me?.role != 'director') {
      // Defence-in-depth: the UI path that opens this sheet already
      // checks isDirector, but refuse here too.
      setState(() => _error = 'Only directors can invite teammates.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final actions = ref.read(inviteActionsProvider);
      final invite = await actions.create(
        spaceId: spaceId,
        role: _role,
        expiry: _expiry,
        email: _emailController.text,
        createdBy: me!.id,
      );
      if (!mounted) return;
      // Swap this sheet for the share view in-place so the director sees
      // the code immediately, no extra navigation.
      Navigator.of(context).pop();
      await InviteShareSheet.show(context, invite: invite);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'invites'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not create invite. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DismissGuard(
      isDirty: _isDirty,
      child: Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text('Invite a teammate', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Pick their role. They join your program by code or '
                    'by signing in with the email below.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Role', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final (value, label) in const [
                        ('director', 'Director'),
                        ('lead_teacher', 'Lead teacher'),
                        ('teacher', 'Teacher'),
                        ('assistant', 'Assistant'),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _role == value,
                          onSelected: (s) {
                            if (s) setState(() => _role = value);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Their email (optional)',
                      hintText: 'jane@example.com',
                      helperText:
                          'If they sign in with this email, they join '
                          'automatically — no code needed.',
                      helperMaxLines: 3,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Expires after', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final option in InviteExpiry.values)
                        ChoiceChip(
                          label: Text(option.label),
                          selected: _expiry == option,
                          onSelected: (s) {
                            if (s) setState(() => _expiry = option);
                          },
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _create,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('Create invite'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
