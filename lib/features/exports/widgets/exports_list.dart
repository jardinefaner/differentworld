import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/exports/exports_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Sent reports" — list of exports tied to one subject. Drops into
/// the subject_detail screen so the audit trail is visible right
/// where the director generates the next one.
///
/// Each row shows: format (PDF / CSV), template name, when, status.
/// Tap → mint a short-lived signed Storage URL and open it in the
/// system viewer (browser for web; system PDF viewer for mobile /
/// desktop). We deliberately don't preview-inline here — past
/// exports are immutable; the only thing the user wants is "show me
/// what I sent."
class ExportsListForSubject extends ConsumerWidget {
  const ExportsListForSubject({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exportsAsync = ref.watch(exportsForSubjectProvider(subjectId));
    return exportsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          'Could not load reports.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      data: (exports) {
        if (exports.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'No reports yet for this child.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final e in exports) _ExportRow(export: e),
          ],
        );
      },
    );
  }
}

class _ExportRow extends ConsumerWidget {
  const _ExportRow({required this.export});
  final Export export;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = DateTime.tryParse(export.generatedAt)?.toLocal();
    return ListTile(
      leading: Icon(
        export.format == 'pdf'
            ? Icons.picture_as_pdf_outlined
            : Icons.table_chart_outlined,
        color: theme.colorScheme.primary,
      ),
      title: Text(_templateLabel(export.templateId)),
      subtitle: Text(
        '${export.format.toUpperCase()} · ${relativeTimeAgo(when)} · '
        '${_statusLabel(export.status)}',
      ),
      trailing: IconButton(
        tooltip: 'Open',
        icon: const Icon(Icons.open_in_new),
        onPressed: () => _open(context, ref, export),
      ),
    );
  }
}

Future<void> _open(
  BuildContext context,
  WidgetRef ref,
  Export export,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await runReported(
    library: 'exports',
    messenger: messenger,
    onError: 'Could not open that report.',
    action: () async {
      final url = await ref
          .read(exportActionsProvider)
          .downloadUrl(export.id);
      if (url == null) {
        messenger?.showSnackBar(
          const SnackBar(
            content: Text(
              "This report has no stored file yet — it's still a draft.",
            ),
          ),
        );
        return;
      }
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    },
  );
}

String _templateLabel(String id) => switch (id) {
      'progress_report' => 'Progress report',
      _ => id,
    };

String _statusLabel(String status) => switch (status) {
      'draft' => 'Draft',
      'sent' => 'Sent',
      'archived' => 'Archived',
      _ => status,
    };
