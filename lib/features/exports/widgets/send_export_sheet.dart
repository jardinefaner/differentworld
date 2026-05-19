import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/exports/exports_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Send / share an already-stored export. Modeless options:
///   - "Email the family" — fans out via the Edge Function
///     (per-guardian checkboxes preloaded with their email)
///   - "Copy link" — mints a 7-day signed URL, copies to clipboard
///
/// Subject-keyed only for v1: we look up the kid's guardians by
/// `export.subject_id`. Program-keyed exports (no subject) get
/// email + the manual-entry path instead.
Future<void> showSendExportSheet(
  BuildContext context, {
  required Export export,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SendExportSheet(export: export),
  );
}

class _SendExportSheet extends ConsumerStatefulWidget {
  const _SendExportSheet({required this.export});
  final Export export;

  @override
  ConsumerState<_SendExportSheet> createState() =>
      _SendExportSheetState();
}

class _SendExportSheetState extends ConsumerState<_SendExportSheet> {
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
    // Capture context-derived state BEFORE any await — `mounted` /
    // `setState` guards the touchpoints after.
    final messenger = ScaffoldMessenger.maybeOf(context);
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
        kind: 'guardian',
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

    final ok = await runReported(
      library: 'exports',
      messenger: messenger,
      onError: 'Email failed to send. Check your network and try again.',
      action: () async {
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
      },
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      return;
    }
    // Defensive — between the mounted check above and here there's
    // no await, but a future refactor could insert one. The cost of
    // the extra `mounted` guard is one comparison; the cost of a
    // setState-after-dispose is a debug-only crash log.
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
    final mq = MediaQuery.of(context);
    final subjectId = widget.export.subjectId;
    final guardiansAsync = subjectId == null
        ? const AsyncValue<List<Guardian>>.data([])
        : ref.watch(_guardiansForSubjectShortProvider(subjectId));

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.send_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Send report', style: theme.textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 8),
              TextField(
                controller: _manualEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Or another email address',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Send by email'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Private provider that watches the guardians attached to a subject.
// Inline here so the send sheet doesn't have to plumb through the
// existing `guardiansForSubjectProvider` (which is in a different
// feature folder and pulls in more deps).
// ignore: specify_nonobvious_property_types
final _guardiansForSubjectShortProvider =
    StreamProvider.autoDispose.family<List<Guardian>, String>(
  (ref, subjectId) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.guardiansDao.watchForSubject(subjectId);
  },
);
