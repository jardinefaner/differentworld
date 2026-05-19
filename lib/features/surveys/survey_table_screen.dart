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

/// `/surveys/:templateId/table` — spreadsheet-style review of every
/// kid's answers for one survey template.
///
/// Rows: subjects in the space (optionally filtered to one classroom).
/// Columns: the template's questions (skipping practice ones).
/// Cells: the kid's answer, formatted compactly per question kind.
///
/// Director scans for patterns ("a third of the class said they don't
/// like reading"), then exports as CSV to share or archive.
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
          // Index answers by subject for fast lookup.
          final answersBySubject = <String, SurveyAnswers>{
            for (final r in responses)
              r.subjectId: SurveyAnswers.fromJson(r.answers),
          };
          // Only scored questions (skip practice ones — they're warm-ups
          // and clutter the comparison view).
          final questions = template.scored.toList();

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
                      '${questions.length} questions',
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
                                questions: questions,
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
                  questions: questions,
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
    required List<SurveyQuestion> questions,
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
        questions: questions,
        answersBySubject: answersBySubject,
      ),
    );
  }

  /// Format the table as CSV, write to a temp file, hand off to the
  /// platform share sheet. On web the share-as-file degrades to a
  /// download via share_plus's web implementation.
  Future<void> _writeAndShareCsv({
    required SurveyTemplate template,
    required List<Subject> subjects,
    required List<SurveyQuestion> questions,
    required Map<String, SurveyAnswers> answersBySubject,
  }) async {
    // Header row.
    final header = <String>[
      'First name',
      'Last name',
      'Classroom',
      'Status',
      for (final q in questions) q.prompt,
    ];
    final rows = <List<String>>[header];
    final groups = ref.read(groupsProvider).value ?? const <Group>[];
    final groupName = {for (final g in groups) g.id: g.name};
    for (final subject in subjects) {
      final answers = answersBySubject[subject.id];
      final status = _statusLabel(answers, questions);
      rows.add([
        subject.firstName,
        subject.lastName,
        groupName[subject.groupId] ?? '',
        status,
        for (final q in questions)
          _formatAnswerForCsv(q, answers),
      ]);
    }
    final csv = rows.map(_csvLine).join('\r\n');
    final fileName =
        '${template.id}-${DateTime.now().toIso8601String().substring(0, 10)}.csv';

    if (kIsWeb) {
      // share_plus on web hands the bytes to the browser as a download.
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8Bytes(csv),
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

/// UTF-8 encoder for the web download path. `dart:io.File` doesn't
/// exist on web, so we hand bytes to share_plus directly there.
Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

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
    required this.questions,
    required this.answersBySubject,
  });

  final List<Subject> subjects;
  final List<SurveyQuestion> questions;
  final Map<String, SurveyAnswers> answersBySubject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Build a Material DataTable inside a horizontal scroll for wide
    // surveys. On phones the user swipes left/right; on iPad+/desktop
    // the whole grid sits inside the screen width.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(
          theme.colorScheme.surfaceContainerHighest,
        ),
        columns: [
          const DataColumn(label: Text('Name')),
          const DataColumn(label: Text('Status')),
          for (final q in questions)
            DataColumn(
              label: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  q.prompt,
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
              questions: questions,
              answers: answersBySubject[subject.id],
            ),
        ],
      ),
    );
  }
}

/// Assemble one row, computing the "done / total" status inline since
/// the questions list is in scope here.
DataRow _row(
  BuildContext context, {
  required Subject subject,
  required List<SurveyQuestion> questions,
  required SurveyAnswers? answers,
}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final total = questions.length;
  var done = 0;
  if (answers != null) {
    for (final q in questions) {
      final has = switch (q.kind) {
        SurveyQuestionKind.agree3 => answers.agree3(q.key) != null,
        SurveyQuestionKind.multiselect =>
          answers.multiselect(q.key).isNotEmpty,
        SurveyQuestionKind.text => answers.text(q.key).isNotEmpty,
      };
      if (has) done++;
    }
  }
  final isComplete = done >= total;
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
      for (final q in questions)
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: _AnswerCell(question: q, answers: answers),
          ),
        ),
    ],
  );
}

/// Renders one cell — what the kid answered for one question. Format
/// depends on the question's kind.
class _AnswerCell extends StatelessWidget {
  const _AnswerCell({required this.question, required this.answers});
  final SurveyQuestion question;
  final SurveyAnswers? answers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (answers == null) {
      return Text('—',
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant));
    }
    return Text(
      _formatAnswerDisplay(question, answers),
      style: theme.textTheme.bodyMedium,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// -- formatters ----------------------------------------------------------

/// Human-readable cell content. Uses emoji for agree3 because it's
/// dense and scannable at a glance.
String _formatAnswerDisplay(SurveyQuestion q, SurveyAnswers? a) {
  if (a == null) return '—';
  switch (q.kind) {
    case SurveyQuestionKind.agree3:
      final v = a.agree3(q.key);
      if (v == null) return '—';
      return switch (v) {
        0 => '😟 No',
        1 => '😐 Maybe',
        2 => '😀 Yes',
        _ => '—',
      };
    case SurveyQuestionKind.multiselect:
      final ks = a.multiselect(q.key);
      if (ks.isEmpty) return '—';
      final labels = <String>[];
      for (final k in ks) {
        final opt = q.options.firstWhere(
          (o) => o.key == k,
          orElse: () => SurveyOption(key: k, label: k),
        );
        labels.add(opt.label);
      }
      return labels.join(', ');
    case SurveyQuestionKind.text:
      final t = a.text(q.key);
      return t.isEmpty ? '—' : t;
  }
}

/// Same content as the display version but without emoji (CSV consumers
/// don't all render emoji uniformly).
String _formatAnswerForCsv(SurveyQuestion q, SurveyAnswers? a) {
  if (a == null) return '';
  switch (q.kind) {
    case SurveyQuestionKind.agree3:
      final v = a.agree3(q.key);
      return switch (v) {
        0 => 'No',
        1 => 'Maybe',
        2 => 'Yes',
        _ => '',
      };
    case SurveyQuestionKind.multiselect:
      final ks = a.multiselect(q.key);
      if (ks.isEmpty) return '';
      final labels = <String>[];
      for (final k in ks) {
        final opt = q.options.firstWhere(
          (o) => o.key == k,
          orElse: () => SurveyOption(key: k, label: k),
        );
        labels.add(opt.label);
      }
      return labels.join('; '); // ; not , so CSV stays unambiguous
    case SurveyQuestionKind.text:
      return a.text(q.key);
  }
}

/// CSV-safe line: each cell quoted if it contains the separator,
/// quotes, or newlines. Quotes inside cells doubled per RFC 4180.
String _csvLine(List<String> cells) {
  return cells.map(_csvField).join(',');
}

String _csvField(String s) {
  final needsQuote =
      s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r');
  if (!needsQuote) return s;
  final escaped = s.replaceAll('"', '""');
  return '"$escaped"';
}

/// Same done/total math the status chip uses, returning a CSV-friendly
/// string instead of a widget.
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
  return n == questions.length ? 'Completed' : 'In progress ($n / ${questions.length})';
}
