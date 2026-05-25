import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/exports/exports_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Send / share an already-stored export.
///
/// Promoted from `send_export_sheet.dart` to the
/// `/exports/:id/send` route in Wave 25. The Export row is passed
/// via go_router `extra` so we don't re-fetch.
///
/// Modeless options:
/// * "Email the family" — fans out via the Edge Function
///   (per-guardian checkboxes preloaded with their email)
/// * "Copy link" — mints a 7-day signed URL, copies to clipboard
///
/// Subject-keyed only for v1: we look up the kid's guardians by
/// `export.subject_id`. Program-keyed exports (no subject) get
/// email + the manual-entry path instead.
class SendExportScreen extends ConsumerStatefulWidget {
  const SendExportScreen({required this.export, super.key});

  final Export export;

  @override
  ConsumerState<SendExportScreen> createState() => _SendExportScreenState();
}

class _SendExportScreenState extends ConsumerState<SendExportScreen> {
  final Set<String> _selectedGuardianIds = <String>{};
  final TextEditingController _manualEmail = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _manualEmail.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final goRouter = GoRouter.of(context);
    setState(() => _sending = true);

    final db = await ref.read(appDatabaseProvider.future);
    final actions = ref.read(exportActionsProvider);

    // Resolve selected guardian rows → emails.
    final guardianRows = <Guardian>[];
    for (final gid in _selectedGuardianIds) {
      final rows = await (db.select(db.guardians)
            ..where((g) => g.id.equals(gid))
            ..limit(1))
          .get();
      if (rows.isNotEmpty) guardianRows.add(rows.first);
    }

    final recipients = <({
      String email,
      String? label,
      String? guardianId,
      String kind,
    })>[];
    for (final g in guardianRows) {
      final email = g.email;
      if (email == null || email.isEmpty) continue;
      recipients.add((
        email: email,
        label: g.name,
        guardianId: g.id,
        kind: ExportRecipientKind.guardian,
      ));
    }
    final manual = _manualEmail.text.trim();
    if (manual.isNotEmpty) {
      recipients.add((
        email: manual,
        label: null,
        guardianId: null,
        kind: 'external',
      ));
    }

    if (recipients.isEmpty) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Pick at least one recipient.')),
      );
      if (mounted) setState(() => _sending = false);
      return;
    }

    // Wrap the send to detect the "your session is no longer valid"
    // path from the Edge Function (happens during / after a Supabase
    // JWT-key rotation). We surface it via a dedicated dialog with
    // a "Sign out" CTA — running the user through `runReported`'s
    // generic snackbar would understate the action they need to take.
    bool ok;
    try {
      final results = await actions.sendByEmail(
        exportId: widget.export.id,
        recipients: recipients,
      );
      final fails = results.where((r) => !r.ok).toList();
      if (!mounted) return;
      if (fails.isEmpty) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Sent to ${results.length} '
              '${results.length == 1 ? 'recipient' : 'recipients'}.',
            ),
          ),
        );
      } else {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Sent ${results.length - fails.length} / '
              '${results.length}; ${fails.length} failed.',
            ),
          ),
        );
      }
      ok = true;
    } on SessionExpiredException catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'exports',
        ),
      );
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Your session expired. Sign out and sign back in to '
            'continue.',
          ),
        ),
      );
      ok = false;
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'exports'),
      );
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(
          content: Text(
            'Email failed to send. Check your network and try again.',
          ),
        ),
      );
      ok = false;
    }
    if (!mounted) return;
    if (ok) {
      if (goRouter.canPop()) goRouter.pop();
      return;
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _copyLink() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final actions = ref.read(exportActionsProvider);
    await runReported(
      library: 'exports',
      messenger: messenger,
      onError: 'Could not mint a shareable link.',
      action: () async {
        final url = await actions.shareableLink(widget.export.id);
        if (url == null) return;
        await Clipboard.setData(ClipboardData(text: url));
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              'Link copied — paste it anywhere. Valid for one week.',
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectId = widget.export.subjectId;
    final guardiansAsync = subjectId == null
        ? const AsyncValue<List<Guardian>>.data([])
        : ref.watch(_guardiansForSubjectShortProvider(subjectId));

    return EdgeScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const ContentHeader(
            title: 'Send report',
            subtitle: 'Email the family or copy a 7-day shareable link.',
          ),
          guardiansAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (guardians) {
              if (guardians.isEmpty) {
                return Text(
                  'No family contacts on file for this child.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Family contacts',
                    style: theme.textTheme.labelMedium,
                  ),
                  for (final g in guardians)
                    CheckboxListTile(
                      value: _selectedGuardianIds.contains(g.id),
                      onChanged: (g.email == null || g.email!.isEmpty)
                          ? null
                          : (v) {
                              setState(() {
                                if (v ?? false) {
                                  _selectedGuardianIds.add(g.id);
                                } else {
                                  _selectedGuardianIds.remove(g.id);
                                }
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(g.name),
                      subtitle: Text(
                        (g.email == null || g.email!.isEmpty)
                            ? 'No email — add one to send'
                            : g.email!,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _manualEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Or another email address',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton.icon(
                onPressed: _copyLink,
                icon: const Icon(Icons.link),
                label: const Text('Copy link'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('Send by email'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Private provider — watches the guardians attached to a subject.
// Inline here so the send screen doesn't have to plumb through the
// existing `guardiansForSubjectProvider` (in a different feature
// folder, pulls in more deps).
// ignore: specify_nonobvious_property_types
final _guardiansForSubjectShortProvider =
    StreamProvider.autoDispose.family<List<Guardian>, String>(
  (ref, subjectId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.guardiansDao.watchForSubject(subjectId);
  },
);
