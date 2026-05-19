import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// `/surveys/:templateId/table` — spreadsheet review of every kid's
/// answers for one survey template.
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
  String? _filterGroupId;

  @override
  Widget build(BuildContext context) {
    final template = SurveyTemplates.byId(widget.templateId);
    if (template == null) {
      return const EdgeScaffold(
        body: Center(child: Text('Survey not found.')),
      );
    }
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final responsesAsync = spaceId == null
        ? const AsyncValue<List<SurveyResponse>>.data([])
        : ref.watch(surveyResponsesProvider(
            (spaceId: spaceId, templateId: widget.templateId),
          ));

    return EdgeScaffold(
      backFallbackRoute: '/surveys/${widget.templateId}',
      actions: const [SyncStatusIndicator()],
      body: subjectsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (allSubjects) {
          final responses =
              responsesAsync.value ?? const <SurveyResponse>[];
          final subjects = _filterGroupId == null
              ? allSubjects
              : allSubjects
                  .where((s) => s.groupId == _filterGroupId)
                  .toList();
          final answersBySubject = <String, SurveyAnswers>{
            for (final r in responses)
              r.subjectId: SurveyAnswers.fromJson(r.answers),
          };
          final cols = _buildColumns(template);

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: '${template.title} · Table',
                  subtitle: '${template.year} · '
                      '${subjects.length} '
                      '${subjects.length == 1 ? 'kid' : 'kids'} · '
                      '${cols.length} columns',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: _GroupFilter(
                        groups: groups,
                        selected: _filterGroupId,
                        onChanged: (id) =>
                            setState(() => _filterGroupId = id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: subjects.isEmpty
                          ? null
                          : () => _exportCsv(
                                template: template,
                                subjects: subjects,
                                cols: cols,
                                answersBySubject: answersBySubject,
                              ),
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
              ),
              if (subjects.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _filterGroupId == null
                        ? 'No children in your program yet.'
                        : 'No children in this classroom.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                _ResponsesGrid(
                  subjects: subjects,
                  cols: cols,
                  answersBySubject: answersBySubject,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportCsv({
    required SurveyTemplate template,
    required List<Subject> subjects,
    required List<_Col> cols,
    required Map<String, SurveyAnswers> answersBySubject,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await runReported(
      library: 'surveys',
      messenger: messenger,
      onError: 'Could not export the CSV.',
      action: () => _writeAndShareCsv(
        template: template,
        subjects: subjects,
        cols: cols,
        answersBySubject: answersBySubject,
      ),
    );
  }

  Future<void> _writeAndShareCsv({
    required SurveyTemplate template,
    required List<Subject> subjects,
    required List<_Col> cols,
    required Map<String, SurveyAnswers> answersBySubject,
  }) async {
    final groups = ref.read(groupsProvider).value ?? const <Group>[];
    final groupName = {for (final g in groups) g.id: g.name};

    final header = <String>[
      'First name',
      'Last name',
      'Classroom',
      'Status',
      for (final c in cols) c.header,
    ];
    final rows = <List<String>>[header];
    for (final subject in subjects) {
      final answers = answersBySubject[subject.id];
      rows.add([
        subject.firstName,
        subject.lastName,
        groupName[subject.groupId] ?? '',
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

/// One column per multiselect option. The cell renders Yes if the
/// option key is in the kid's pick list, No if it's not.
///
/// Note: "No" is ambiguous between "kid said no" and "kid hasn't
/// answered this question yet" — we render `—` when the kid has NO
/// answer recorded for the parent question (i.e. no response row at
/// all), and only fall back to "No" once there's a response with at
/// least one option picked elsewhere on this question.
class _MultiOptCol extends _Col {
  _MultiOptCol(this.q, this.opt);
  final SurveyQuestion q;
  final SurveyOption opt;

  @override
  String get header => '${q.prompt} — ${opt.label}';

  @override
  String display(SurveyAnswers? a) {
    if (a == null) return '—';
    final picks = a.multiselect(q.key);
    if (picks.contains(opt.key)) return '✓ Yes';
    // Heuristic for "answered no" vs "not answered": if the kid has
    // ANY pick on this question, they engaged with it; missing keys
    // are deliberate Nos.
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
  for (final q in t.scored) {
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

class _GroupFilter extends StatelessWidget {
  const _GroupFilter({
    required this.groups,
    required this.selected,
    required this.onChanged,
  });

  final List<Group> groups;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selected,
      decoration: const InputDecoration(
        labelText: 'Classroom filter',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String?>(
          child: Text('All classrooms'),
        ),
        for (final g in groups)
          DropdownMenuItem<String?>(value: g.id, child: Text(g.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _ResponsesGrid extends StatelessWidget {
  const _ResponsesGrid({
    required this.subjects,
    required this.cols,
    required this.answersBySubject,
  });

  final List<Subject> subjects;
  final List<_Col> cols;
  final Map<String, SurveyAnswers> answersBySubject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          theme.colorScheme.surfaceContainerHighest,
        ),
        columns: [
          const DataColumn(label: Text('Name')),
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
          for (final subject in subjects)
            _row(
              context,
              subject: subject,
              cols: cols,
              answers: answersBySubject[subject.id],
            ),
        ],
      ),
    );
  }
}

DataRow _row(
  BuildContext context, {
  required Subject subject,
  required List<_Col> cols,
  required SurveyAnswers? answers,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final total = cols.length;
  var done = 0;
  if (answers != null) {
    for (final c in cols) {
      if (c.csv(answers).isNotEmpty) done++;
    }
  }
  final isComplete = done >= total && total > 0;
  final statusChip = answers == null
      ? Text('—', style: TextStyle(color: scheme.onSurfaceVariant))
      : Container(
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
              color: isComplete
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
  return DataRow(
    cells: [
      DataCell(Text('${subject.firstName} ${subject.lastName}')),
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
