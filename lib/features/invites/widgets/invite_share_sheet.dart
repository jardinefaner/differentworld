import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/invites/invite_code.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

/// Director-facing view of a single pending invite. Shown right after
/// creation, and also when tapping an existing pending invite in the
/// Team screen.
///
/// Affordances: code in big type, QR (scans to the deep link), Copy
/// button, native Share, Revoke.
class InviteShareSheet extends ConsumerStatefulWidget {
  const InviteShareSheet({required this.invite, super.key});

  final Invite invite;

  static Future<void> show(
    BuildContext context, {
    required Invite invite,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => InviteShareSheet(invite: invite),
    );
  }

  @override
  ConsumerState<InviteShareSheet> createState() => _InviteShareSheetState();
}

class _InviteShareSheetState extends ConsumerState<InviteShareSheet> {
  bool _revoking = false;

  Future<void> _revoke() async {
    if (_revoking) return;
    setState(() => _revoking = true);
    try {
      await ref.read(inviteActionsProvider).revoke(widget.invite.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not revoke. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = widget.invite;
    final theme = Theme.of(context);
    final code = invite.code;
    final deepLink = code == null ? null : InviteCode.deepLinkFor(code);
    // TODO(invites): wire program name from a space provider so the
    // share text reads "Join Sunshine Preschool on Different World."
    final shareText = code == null
        ? null
        : InviteCode.shareTextFor(code: code);

    return Padding(
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
              Text('Invite ready', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                _subtitleFor(invite),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
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
                    child: QrImageView(
                      data: deepLink!,
                      size: 220,
                    ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    // 6-char codes read better as "ABC-DEF".
    if (code.length == 6) return '${code.substring(0, 3)}-${code.substring(3)}';
    return code;
  }

  static String _roleLabel(String role) => switch (role) {
        'director' => 'Director',
        'lead_teacher' => 'Lead teacher',
        'teacher' => 'Teacher',
        'assistant' => 'Assistant',
        _ => role,
      };

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
