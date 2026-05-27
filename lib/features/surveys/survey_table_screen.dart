import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// `/surveys/:templateId/table` — Wave 138: anonymous spreadsheet
/// review.
///
/// Before: one row per kid in the program, joined to their survey
/// response. After: one row per RESPONSE — each "Start a new survey"
/// produces a fresh row with no kid linkage. Identity columns
/// (age band / grade / school) take the place of the name column.
///
/// Columns are *answer slots* — one per agree3/text question, and one
/// per option for multiselect questions (so a 3-option multiselect
/// becomes 3 columns of Yes/No instead of one comma-joined cell).
/// CSV export uses the same slot layout for easy import into Sheets.
class SurveyTableScreen extends ConsumerStatefulWidget {
  const SurveyTableScreen({required this.templateId, super.key});

  final String templateId;

  @override
  ConsumerState<SurveyTableScreen> createState() =>
      _SurveyTableScreenState();
}

class _SurveyTableScreenState extends ConsumerState<SurveyTableScreen> {
  /// Filter rows by completion status: null = all, 'completed' /
  /// 'draft' = matching only.
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final template = SurveyTemplates.byId(widget.templateId);
    if (template == null) {
      return const EdgeScaffold(
        body: EmptyState(
          icon: Icons.quiz_outlined,
          title: 'Survey not found',
        ),
      );
    }
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    final responsesAsync = spaceId == null
        ? const AsyncValue<List<SurveyResponse>>.data([])
        : ref.watch(surveyResponsesProvider(
            (spaceId: spaceId, templateId: widget.templateId),
          ));

    return EdgeScaffold(
      backFallbackRoute: '/surveys/${widget.templateId}',
      actions: const [SyncStatusIndicator()],
      body: responsesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load',
          onRetry: () => ref.invalidate(surveyResponsesProvider(
            (
              spaceId: spaceId ?? '',
              templateId: widget.templateId,
            ),
          )),
        ),
        data: (allResponses) {
          final responses = _statusFilter == null
              ? allResponses
              : allResponses
                  .where((r) => r.status == _statusFilter)
                  .toList();
          final cols = _buildColumns(template);

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: '${template.title} · Table',
                  subtitle: '${template.year} · '
                      '${responses.length} '
                      '${responses.length == 1 ? 'response' : 'responses'} · '
                      '${cols.length} columns',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatusFilter(
                        selected: _statusFilter,
                        onChanged: (s) =>
                            setState(() => _statusFilter = s),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: responses.isEmpty
                          ? null
                          : () => _exportCsv(
                                template: template,
                                responses: responses,
                                cols: cols,
                              ),
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
              ),
              if (responses.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _statusFilter == null
                        ? 'No responses recorded yet.'
                        : 'No matching responses.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                _ResponsesGrid(
                  responses: responses,
                  cols: cols,
                  template: template,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCsv({
    required SurveyTemplate template,
    required List<SurveyResponse> responses,
    required List<_Col> cols,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await runReported(
      library: 'surveys',
      messenger: messenger,
      onError: 'Could not export the CSV.',
      action: () => _writeAndShareCsv(
        template: template,
        responses: responses,
        cols: cols,
      ),
    );
  }

  Future<void> _writeAndShareCsv({
    required SurveyTemplate template,
    required List<SurveyResponse> responses,
    required List<_Col> cols,
  }) async {
    // Wave 138: anonymized export. Identity columns + status + the
    // answer slots; no kid name, no classroom.
    final header = <String>[
      'Recorded at',
      'Age band',
      'Grade',
      'School',
      'Status',
      for (final c in cols) c.header,
    ];
    final rows = <List<String>>[header];
    for (final r in responses) {
      final answers = SurveyAnswers.fromJson(r.answers);
      rows.add([
        _formatTimestamp(r.completedAt ?? r.updatedAt),
        r.ageBand ?? '',
        r.grade ?? '',
        r.school ?? '',
        _statusLabel(answers, template.scored.toList()),
        for (final c in cols) c.csv(answers),
      ]);
    }
    final csv = rows.map(_csvLine).join('\r\n');
    final fileName =
        '${template.id}-${DateTime.now().toIso8601String().substring(0, 10)}.csv';

    if (kIsWeb) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              _utf8Bytes(csv),
              name: fileName,
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: [fileName],
        ),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }
}

String _formatTimestamp(String iso) {
  // Trim to "YYYY-MM-DD HH:MM" for readability. Robust to either
  // ISO date-time format (with or without trailing Z / fractional).
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

Uint8List _utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

// ---------------------------------------------------------------------------
// Column specs — one per answer slot. Multiselect questions expand to
// one column per option (each cell = Yes/No). Agree3 + text are 1:1.
// ---------------------------------------------------------------------------

sealed class _Col {
  String get header;

  /// Human-readable cell content for the on-screen DataTable.
  String display(SurveyAnswers? a);

  /// Same content shaped for CSV (no emoji; multiselect-option columns
  /// are Yes/No so the values line up across rows cleanly).
  String csv(SurveyAnswers? a);
}

class _Agree3Col extends _Col {
  _Agree3Col(this.q);
  final SurveyQuestion q;

  @override
  String get header => q.prompt;

  @override
  String display(SurveyAnswers? a) {
    if (a == null) return '—';
    final v = a.agree3(q.key);
    return switch (v) {
      0 => '😟 No',
      1 => '😐 Maybe',
      2 => '😀 Yes',
      _ => '—',
    };
  }

  @override
  String csv(SurveyAnswers? a) {
    if (a == null) return '';
    final v = a.agree3(q.key);
    return switch (v) {
      0 => 'No',
      1 => 'Maybe',
      2 => 'Yes',
      _ => '',
    };
  }
}

class _MultiOptCol extends _Col {
  _MultiOptCol(this.q, this.opt);
  final SurveyQuestion q;
  final SurveyOption opt;

  // Wave 145: option labels are now self-contained "Did you...?"
  // questions, so the parent prompt prefix ("Check any of the
  // activities…") is redundant noise in the CSV header. Use the
  // option label directly.
  @override
  String get header => opt.label;

  @override
  String display(SurveyAnswers? a) {
    if (a == null) return '—';
    final picks = a.multiselect(q.key);
    if (picks.contains(opt.key)) return '✓ Yes';
    if (picks.isNotEmpty) return 'No';
    return '—';
  }

  @override
  String csv(SurveyAnswers? a) {
    if (a == null) return '';
    final picks = a.multiselect(q.key);
    if (picks.contains(opt.key)) return 'Yes';
    if (picks.isNotEmpty) return 'No';
    return '';
  }
}

class _TextCol extends _Col {
  _TextCol(this.q);
  final SurveyQuestion q;

  @override
  String get header => q.prompt;

  @override
  String display(SurveyAnswers? a) {
    if (a == null) return '—';
    final t = a.text(q.key);
    return t.isEmpty ? '—' : t;
  }

  @override
  String csv(SurveyAnswers? a) {
    if (a == null) return '';
    return a.text(q.key);
  }
}

List<_Col> _buildColumns(SurveyTemplate t) {
  final out = <_Col>[];
  for (final q in t.questions) {
    switch (q.kind) {
      case SurveyQuestionKind.agree3:
        out.add(_Agree3Col(q));
      case SurveyQuestionKind.multiselect:
        for (final opt in q.options) {
          out.add(_MultiOptCol(q, opt));
        }
      case SurveyQuestionKind.text:
        out.add(_TextCol(q));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// UI bits.
// ---------------------------------------------------------------------------

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({
    required this.selected,
    required this.onChanged,
  });

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Status filter',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem<String?>(child: Text('All responses')),
        DropdownMenuItem<String?>(
          value: SurveyResponseStatus.completed,
          child: Text('Completed only'),
        ),
        DropdownMenuItem<String?>(
          value: SurveyResponseStatus.draft,
          child: Text('Drafts only'),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ResponsesGrid extends ConsumerWidget {
  const _ResponsesGrid({
    required this.responses,
    required this.cols,
    required this.template,
  });

  final List<SurveyResponse> responses;
  final List<_Col> cols;
  final SurveyTemplate template;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          theme.colorScheme.surfaceContainerHighest,
        ),
        columns: [
          const DataColumn(label: Text('')), // delete column
          const DataColumn(label: Text('Recorded')),
          const DataColumn(label: Text('Age band')),
          const DataColumn(label: Text('Grade')),
          const DataColumn(label: Text('School')),
          const DataColumn(label: Text('Status')),
          for (final c in cols)
            DataColumn(
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  c.header,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
        rows: [
          for (final r in responses)
            _row(
              context,
              ref: ref,
              response: r,
              cols: cols,
              template: template,
            ),
        ],
      ),
    );
  }
}

DataRow _row(
  BuildContext context, {
  required WidgetRef ref,
  required SurveyResponse response,
  required List<_Col> cols,
  required SurveyTemplate template,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final answers = SurveyAnswers.fromJson(response.answers);
  final total = cols.length;
  var done = 0;
  for (final c in cols) {
    if (c.csv(answers).isNotEmpty) done++;
  }
  final isComplete = response.status == SurveyResponseStatus.completed;
  final statusChip = Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: isComplete
          ? scheme.primary.withValues(alpha: 0.15)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      isComplete ? 'Complete' : '$done / $total',
      style: theme.textTheme.labelSmall?.copyWith(
        color: isComplete ? scheme.primary : scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
  return DataRow(
    cells: [
      DataCell(
        // Wave 166.1: per-row delete affordance. Tap → confirm sheet
        // → SurveyActions.reset(id). Rows are anonymous so no PII is
        // surfaced in the confirm copy; just "this response."
        IconButton(
          tooltip: 'Delete this response',
          icon: Icon(
            Icons.delete_outline,
            color: scheme.error.withValues(alpha: 0.85),
            size: 20,
          ),
          onPressed: () async {
            final timestamp = _formatTimestamp(
              response.completedAt ?? response.updatedAt,
            );
            final identityBits = <String>[
              if (response.ageBand != null) response.ageBand!,
              if (response.grade != null) response.grade!,
              if (response.school != null) response.school!,
            ];
            final identity = identityBits.isEmpty
                ? 'no identity recorded'
                : identityBits.join(' · ');
            final confirmed = await confirmDestructive(
              context,
              title: 'Delete this response?',
              message:
                  'Recorded $timestamp · $identity. This removes '
                  'just this row from the table — the template '
                  'itself stays put. This action cannot be undone.',
            );
            if (!confirmed) return;
            await ref
                .read(surveyActionsProvider)
                .reset(id: response.id);
          },
        ),
      ),
      DataCell(Text(_formatTimestamp(
          response.completedAt ?? response.updatedAt))),
      DataCell(Text(response.ageBand ?? '—')),
      DataCell(Text(response.grade ?? '—')),
      DataCell(Text(response.school ?? '—')),
      DataCell(statusChip),
      for (final c in cols)
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              c.display(answers),
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// CSV serialization (RFC 4180-ish: CRLF lines, quote on commas/quotes/
// newlines, double quotes for embedded ones).
// ---------------------------------------------------------------------------

String _csvLine(List<String> cells) => cells.map(_csvField).join(',');

String _csvField(String s) {
  final needsQuote =
      s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
  if (!needsQuote) return s;
  final escaped = s.replaceAll('"', '""');
  return '"$escaped"';
}

String _statusLabel(SurveyAnswers? a, List<SurveyQuestion> questions) {
  if (a == null) return 'Not started';
  var n = 0;
  for (final q in questions) {
    final has = switch (q.kind) {
      SurveyQuestionKind.agree3 => a.agree3(q.key) != null,
      SurveyQuestionKind.multiselect => a.multiselect(q.key).isNotEmpty,
      SurveyQuestionKind.text => a.text(q.key).isNotEmpty,
    };
    if (has) n++;
  }
  if (n == 0) return 'Not started';
  return n == questions.length
      ? 'Completed'
      : 'In progress ($n / ${questions.length})';
}
