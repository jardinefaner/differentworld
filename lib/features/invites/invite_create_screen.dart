import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Create a new staff invite — role + optional email + expiration.
/// Promoted from `invite_create_sheet.dart` to the
/// `/settings/team/invite/new` route in Wave 24. After creation we
/// `pushReplacement` to `/settings/team/invite/:id` so back from the
/// share screen returns to Team, not to this create form.
class InviteCreateScreen extends ConsumerStatefulWidget {
  const InviteCreateScreen({super.key});

  @override
  ConsumerState<InviteCreateScreen> createState() =>
      _InviteCreateScreenState();
}

class _InviteCreateScreenState extends ConsumerState<InviteCreateScreen> {
  final _emailController = TextEditingController();

  /// Default role for a new invite. Initialised in `build` from the
  /// active vertical's role list (first non-admin role — e.g. childcare
  /// 'teacher', construction 'foreman', healthcare 'rn'). Stays `null`
  /// until the first build so the picker doesn't seed with a value
  /// that's wrong for the current vertical.
  String? _role;
  InviteExpiry _expiry = InviteExpiry.sevenDays;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving) return;
    final me = ref.read(currentMemberProvider).value;
    final spaceId = me?.spaceId;
    if (spaceId == null) {
      setState(() => _error = 'No program selected.');
      return;
    }
    if (!ref.read(viewerProvider).canInviteStaff) {
      setState(() => _error = "You don't have permission to invite.");
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
        role: _role ?? 'teacher',
        expiry: _expiry,
        email: _emailController.text,
        createdBy: me!.id,
      );
      if (!mounted) return;
      // Swap this screen for the share view so back from share goes
      // back to Team, not into the create form.
      context.pushReplacement(
        '/settings/team/invite/${invite.id}',
        extra: invite,
      );
    } on Object catch (e, st) {
      // on Object, not on Exception: the repo can throw a StateError
      // ("No Space"), and the me!.id unwrap a TypeError — both Error
      // subtypes that would escape `on Exception` and red-screen
      // instead of surfacing the inline retry.
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
    // Roles offered per active vertical — childcare's director /
    // lead_teacher / teacher / substitute / specialist / kitchen,
    // construction's pm / foreman / etc. Drives both the chip labels
    // and the role key written into the invite row.
    final labels = ref.watch(verticalLabelsProvider);
    final roles = RoleBundles.rolesFor(labels.vertical);
    // Seed the picker with the most "common-staff" role for this
    // vertical (last in the rolesFor list = least-senior). Could be
    // configurable; for now it's "the role you most often invite."
    final defaultRole = roles.isEmpty
        ? 'teacher'
        : roles.length > 2
            ? roles[roles.length - 2]
            : roles.last;
    final selected = _role ?? defaultRole;
    final bento = bentoEnabled(ref, perScreen: null);

    return EdgeScaffold(
      backFallbackRoute: '/settings/team',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoCol = bento && constraints.maxWidth >= _twoColMinWidth;

          // Role picker — label + choice chips. Carries a stable key so it
          // survives moving between the single-column and 2-column slots.
          final roleBlock = Column(
            key: const ValueKey('invite-role-block'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Role', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in roles)
                    ChoiceChip(
                      label: Text(
                        RoleLabels.of(key, vertical: labels.vertical),
                      ),
                      selected: selected == key,
                      onSelected: (s) {
                        if (s) setState(() => _role = key);
                      },
                    ),
                ],
              ),
            ],
          );

          // Specialist hint — invite carries the role only; the specialty
          // (coach / tutor / etc.) is set per-member on the Team detail
          // screen after they accept. Surfacing the hint here so the
          // director knows what to do next instead of hunting for a
          // specialty field that isn't on the invite. Full-width in both
          // layouts.
          final specialistHint = Container(
            key: const ValueKey('invite-specialist-hint'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiaryContainer.withValues(
                alpha: 0.4,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 18,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'After they accept, open their profile in Team to '
                    'set their specialty (coach, tutor, health aide, '
                    'and others).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          );

          final emailField = TextField(
            key: const ValueKey('invite-email'),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            // Wave 111: tag for browser autofill / password-manager
            // helpers. Lets a director typing a teammate's email
            // pick from their address book / saved contacts.
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Their email (optional)',
              hintText: 'jane@example.com',
              helperText: 'If they sign in with this email, they join '
                  'automatically — no code needed.',
              helperMaxLines: 3,
              border: OutlineInputBorder(),
            ),
          );

          // Expiry picker — label + choice chips. Short, pairs with the
          // email field in 2-column mode (email left, expiry right) so the
          // field order Role → email → expiry is preserved.
          final expiryBlock = Column(
            key: const ValueKey('invite-expiry-block'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Expires after', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
            ],
          );

          // email (left) + expiry (right) pair in 2-col; stacked otherwise.
          final emailAndExpiry = twoCol
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: emailField),
                    const SizedBox(width: 16),
                    Expanded(child: expiryBlock),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    emailField,
                    const SizedBox(height: 20),
                    expiryBlock,
                  ],
                );

          return FormBody(
            // Widen so the email + expiry pair fits side by side in 2-col;
            // the single-column form keeps the comfortable reading width.
            maxWidth: twoCol ? 900 : Breakpoints.contentMaxWidth,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              const ContentHeader(
                title: 'Invite a teammate',
                subtitle: 'Pick their role. They join by code or by signing '
                    'in with the email below.',
              ),
              roleBlock,
              if (selected == 'specialist') ...[
                const SizedBox(height: 12),
                specialistHint,
              ],
              const SizedBox(height: 20),
              emailAndExpiry,
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
                  FilledButton.icon(
                    onPressed: _saving ? null : _create,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Create invite'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  /// Two short fields pair up at this width and wider (tablet portrait+).
  /// No shared constant sits exactly here (`Breakpoints.smallTablet` is
  /// 840); kept local for the "grids everywhere" sweep.
  static const double _twoColMinWidth = 720;
}
