import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/exports/exports_providers.dart';
import 'package:differentworld/features/exports/signed_export_url.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Recent reports" surface on Family Today — the progress-report PDFs the
/// staff have sent the guardian. Closes the last Tier-B item from the
/// 2026-05-23 persona-audit (Lauren / Devon / Helen / Marcus).
///
/// Renders nothing when the inbox is empty, so the card never adds chrome on a
/// quiet day. Shows at most three rows; a "View all" affordance is deferred —
/// once a family has more than a handful of rows the per-child detail screen
/// will absorb the overflow.
///
/// Tap → mint a 10-minute signed Storage URL and hand it to `url_launcher`. The
/// OS picks a PDF viewer (Drive, browser, third-party reader); we don't host an
/// in-app PDF viewer because Lauren likely already trusts a system viewer for
/// the receipts she gets in email.
class ReceivedReportsCard extends ConsumerWidget {
  const ReceivedReportsCard({required this.subjectsById, super.key});

  /// Map of `subject.id → Subject` so each report row can render the
  /// child's first name without an extra DB lookup per row. Family
  /// Today already has the children list loaded.
  final Map<String, Subject> subjectsById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportsAsync = ref.watch(myReceivedExportsProvider);
    final exports = exportsAsync.value ?? const <ReceivedExport>[];
    if (exports.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = exports.length > 3 ? exports.sublist(0, 3) : exports;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    exports.length == 1 ? 'Recent report' : 'Recent reports',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (exports.length > visible.length)
                    Text(
                      '+${exports.length - visible.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            for (final e in visible)
              _ReceivedReportRow(
                export: e,
                subjectName: e.subjectId == null
                    ? null
                    : subjectsById[e.subjectId]?.firstName,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedReportRow extends ConsumerStatefulWidget {
  const _ReceivedReportRow({required this.export, required this.subjectName});

  final ReceivedExport export;
  final String? subjectName;

  @override
  ConsumerState<_ReceivedReportRow> createState() => _ReceivedReportRowState();
}

class _ReceivedReportRowState extends ConsumerState<_ReceivedReportRow> {
  bool _opening = false;

  /// Mint a 10-minute signed Storage URL from the export's path and
  /// hand it to the OS. 10 minutes is the existing convention — enough
  /// to view, not enough to ship the URL into an email and have it
  /// still work in an hour. (Sharing is what the staff `send` action
  /// is for.) The path comes from the direct PostgREST query in
  /// `myReceivedExportsProvider`; we don't go through the Drift mirror
  /// `ExportActions.downloadUrl` because the local Drift `exports`
  /// table is empty for guardians (by_space sync stream limitation).
  ///
  /// Also stamps the guardian's `export_recipients.read_at` (Devon
  /// persona, Wave 42) — fire-and-forget so a slow round-trip doesn't
  /// block the launchUrl. The card refreshes via provider invalidation
  /// once the round-trip lands, so the "Seen" badge appears on next
  /// rebuild. Errors on the mark-read are swallowed (the user already
  /// has the PDF open by then; a missed timestamp isn't worth a
  /// snackbar).
  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final path = widget.export.storagePath;
      if (path == null) {
        if (!mounted) return;
        messenger?.showSnackBar(
          const SnackBar(
            content: Text("This report isn't ready to view yet."),
          ),
        );
        return;
      }
      final url = await mintExportSignedUrl(path);
      if (!mounted) return;
      final uri = Uri.parse(url);
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!ok) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't open the report. Try again or check email.",
            ),
          ),
        );
        return;
      }
      // PDF opened successfully — stamp read_at + refresh the card so
      // the "Seen" badge shows on next rebuild. Done in the background
      // because the user already has the document open.
      final viewer = ref.read(viewerProvider);
      if (viewer is GuardianViewer && widget.export.myReadAt == null) {
        unawaited(
          markReceivedExportRead(
            exportId: widget.export.id,
            guardianId: viewer.guardian.id,
          ).then(
            (_) {
              if (mounted) ref.invalidate(myReceivedExportsProvider);
            },
            onError: (Object _, _) {
              // Swallow — user has the PDF; missed stamp isn't fatal.
            },
          ),
        );
      }
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'family'),
      );
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not load the report.')),
      );
    } finally {
      // The `if (!mounted) return` early-exits inside the try block
      // each guard `setState` with their own mounted check; this
      // finally still runs but is guarded too, so the unmounted path
      // is safe end-to-end.
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sentRaw = widget.export.sentAt;
    final sent = sentRaw == null ? null : DateTime.tryParse(sentRaw)?.toLocal();
    final label = widget.subjectName == null
        ? 'Progress report'
        : '${widget.subjectName} · Progress report';
    final subtitle = sent == null
        ? 'Sent recently'
        : 'Sent ${DateFormat.yMMMd().add_jm().format(sent)}';
    // Devon persona (Wave 42): once the guardian taps to open the
    // PDF, their `export_recipients.read_at` is stamped. The check-
    // mark badge on subsequent rebuilds tells the parent which
    // reports they've already worked through — useful when 3 PDFs
    // arrive on a Monday morning.
    final hasBeenRead = widget.export.myReadAt != null;
    return InkWell(
      onTap: _opening ? null : _open,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: [
            Icon(
              hasBeenRead ? Icons.task_alt : Icons.description_outlined,
              size: 20,
              color: hasBeenRead ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hasBeenRead
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasBeenRead ? '$subtitle · Seen' : subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: hasBeenRead ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            if (_opening)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.open_in_new,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
