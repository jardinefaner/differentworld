import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/invites/invite_code.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Director-facing view of a single pending invite — code in big
/// type, QR (scans the deep link), Copy, native Share, Revoke.
///
/// Promoted from `invite_share_sheet.dart` to
/// `/settings/team/invite/:id` in Wave 24. Reached after creation
/// (via `pushReplacement` from `InviteCreateScreen`) and from
/// tapping a pending-invite row in Team.
///
/// The full `Invite` row is passed via go_router `extra` so we don't
/// re-fetch by id — the caller already has it. Pop returns to Team.
class InviteShareScreen extends ConsumerStatefulWidget {
  const InviteShareScreen({required this.invite, super.key});

  final Invite invite;

  @override
  ConsumerState<InviteShareScreen> createState() => _InviteShareScreenState();
}

class _InviteShareScreenState extends ConsumerState<InviteShareScreen> {
  bool _revoking = false;

  Future<void> _revoke() async {
    if (_revoking) return;
    setState(() => _revoking = true);
    final messenger = ScaffoldMessenger.of(context);
    final goRouter = GoRouter.of(context);
    try {
      await ref.read(inviteActionsProvider).revoke(widget.invite.id);
      if (!mounted) return;
      if (goRouter.canPop()) goRouter.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Invite revoked'),
          duration: Duration(seconds: 2),
        ),
      );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'invites'),
      );
      if (!mounted) return;
      setState(() => _revoking = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not revoke. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final theme = Theme.of(context);
    final code = invite.code;
    // Wave 165.3: use the HTTPS form so OS-camera scans land on the
    // static fallback page (which handles the deep-link handoff with
    // an "Open in app" affordance).
    //
    // Wave 170: encode the github.io project-page URL while DNS for
    // differentworld.app is unresolved. The in-app listener still
    // accepts the custom scheme + apex form too — see
    // `InviteCode.extractFromUri`.
    final deepLink = code == null ? null : InviteCode.pagesLinkFor(code);
    // Personalise the share blurb with the current program name. May
    // be null pre-sync; degrades to the generic copy in that case.
    final programName = ref.watch(currentSpaceProvider).value?.name;
    final shareText = code == null
        ? null
        : InviteCode.shareTextFor(code: code, programName: programName);

    return EdgeScaffold(
      backFallbackRoute: '/settings/team',
      body: FormBody(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          ContentHeader(
            title: 'Invite ready',
            subtitle: _subtitleFor(invite),
          ),
          if (code != null) ...[
            Center(
              child: SelectableText(
                _formatCode(code),
                style: theme.textTheme.displayMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: QrImageView(data: deepLink!, size: 220),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Scan to join',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.content_copy_outlined),
                  label: const Text('Copy code'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async {
                    final text = shareText;
                    if (text == null) return;
                    await SharePlus.instance.share(
                      ShareParams(
                        text: text,
                        subject: 'Different World invite',
                      ),
                    );
                  },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share'),
                ),
              ],
            ),
          ] else
            Text(
              'This invite has no code — it will auto-match when '
              '${invite.email ?? 'the recipient'} signs in.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Role'),
            trailing: Text(
              _roleLabel(invite.role),
              style: theme.textTheme.bodyLarge,
            ),
          ),
          if (invite.email != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Email'),
              trailing: Text(
                invite.email!,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expires'),
            trailing: Text(
              _expiresLabel(invite.expiresAt),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _revoking ? null : _revoke,
                icon: _revoking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.delete_outline,
                        color: theme.colorScheme.error,
                      ),
                label: Text(
                  'Revoke',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _subtitleFor(Invite invite) {
    if (invite.email != null) {
      return 'Share the code below, or have ${invite.email} sign in '
          'with that email to join automatically.';
    }
    return 'Share the code below to bring them into your program.';
  }

  static String _formatCode(String code) {
    if (code.length == 6) {
      return '${code.substring(0, 3)}-${code.substring(3)}';
    }
    return code;
  }

  static String _roleLabel(String role) => RoleLabels.of(role);

  static String _expiresLabel(String? iso) {
    if (iso == null) return 'Never';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Never';
    final delta = dt.difference(DateTime.now().toUtc());
    if (delta.isNegative) return 'Expired';
    if (delta.inDays >= 1) return 'in ${delta.inDays}d';
    if (delta.inHours >= 1) return 'in ${delta.inHours}h';
    return 'in ${delta.inMinutes}m';
  }
}
