import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/exports/templates/progress_report.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// `/subjects/:subjectId/progress-report` — assembles a per-kid
/// progress report PDF and shows a live preview. Director scrubs,
/// then prints, saves, or shares.
class ProgressReportScreen extends ConsumerStatefulWidget {
  const ProgressReportScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  ConsumerState<ProgressReportScreen> createState() =>
      _ProgressReportScreenState();
}

class _ProgressReportScreenState
    extends ConsumerState<ProgressReportScreen> {
  // Lookback for attendance + observations. Default 30 days — wide
  // enough for a parent-teacher conference snapshot, narrow enough
  // that the report doesn't balloon into a year-in-review document.
  int _windowDays = 30;

  @override
  Widget build(BuildContext context) {
    final subjectAsync =
        ref.watch(subjectByIdProvider(widget.subjectId));
    final viewer = ref.watch(viewerProvider);
    final space = viewer.space;
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: subjectAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (subject) {
          if (subject == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'Child not found',
            );
          }
          final groupName = groups
              .where((g) => g.id == subject.groupId)
              .map((g) => g.name)
              .firstOrNull;
          final observations = ref
                  .watch(entriesForSubjectProvider(
                    (subjectId: subject.id, kind: 'observation'),
                  ))
                  .value ??
              const <Entry>[];
          final attendance = ref
                  .watch(attendanceForSubjectProvider(subject.id))
                  .value ??
              const <AttendanceRecord>[];

          final cutoff = DateTime.now().subtract(Duration(days: _windowDays));
          final recentObs = observations
              .where((e) {
                final dt = DateTime.tryParse(e.recordedAt);
                return dt != null && dt.isAfter(cutoff);
              })
              .toList();
          final summary = _summarizeAttendance(attendance, _windowDays);

          // Pull every survey the kid has answered.
          final surveys = <SurveySummary>[];
          for (final template in SurveyTemplates.all) {
            final response = ref
                .watch(surveyResponseProvider(
                  (
                    templateId: template.id,
                    subjectId: subject.id,
                  ),
                ))
                .value;
            if (response == null) continue;
            surveys.add(
              SurveySummary(
                template: template,
                answers: SurveyAnswers.fromJson(response.answers),
              ),
            );
          }

          final data = ProgressReportData(
            subject: subject,
            spaceName: space?.name,
            groupName: groupName,
            observations: recentObs,
            attendanceSummary: summary,
            surveySummaries: surveys,
            generatedAt: DateTime.now(),
          );

          return Column(
            children: [
              const SizedBox(height: 56),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Progress report',
                  subtitle:
                      '${subject.firstName} ${subject.lastName} · '
                      'last $_windowDays days',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _WindowSelect(
                        days: _windowDays,
                        onChanged: (d) =>
                            setState(() => _windowDays = d),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _shareOrPrint(data),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share / Print'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PdfPreview(
                  build: (format) async {
                    final doc = await buildProgressReportPdf(data);
                    return doc.save();
                  },
                  // Hide the built-in toolbar — the Share button above
                  // is the canonical entry point so we don't have two
                  // affordances doing the same thing.
                  allowPrinting: false,
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _shareOrPrint(ProgressReportData data) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await runReported(
      library: 'exports',
      messenger: messenger,
      onError: 'Could not generate the report.',
      action: () async {
        final doc = await buildProgressReportPdf(data);
        final bytes = await doc.save();
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'progress-${data.subject.firstName.toLowerCase()}-'
              '${data.generatedAt.toIso8601String().substring(0, 10)}.pdf',
        );
      },
    );
  }

  AttendanceSummary _summarizeAttendance(
    List<AttendanceRecord> records,
    int windowDays,
  ) {
    final cutoff = DateTime.now().subtract(Duration(days: windowDays));
    var present = 0;
    var absent = 0;
    var late = 0;
    var earlyPickup = 0;
    var excused = 0;
    for (final r in records) {
      final dt = DateTime.tryParse(r.date);
      if (dt == null || dt.isBefore(cutoff)) continue;
      switch (r.status) {
        case 'present':
          present++;
        case 'absent':
          absent++;
        case 'late':
          late++;
        case 'early_pickup':
          earlyPickup++;
        case 'excused':
          excused++;
      }
    }
    return AttendanceSummary(
      windowDays: windowDays,
      present: present,
      absent: absent,
      late: late,
      earlyPickup: earlyPickup,
      excused: excused,
    );
  }
}

class _WindowSelect extends StatelessWidget {
  const _WindowSelect({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: days,
      decoration: const InputDecoration(
        labelText: 'Time window',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: const [
        DropdownMenuItem(value: 7, child: Text('Last 7 days')),
        DropdownMenuItem(value: 30, child: Text('Last 30 days')),
        DropdownMenuItem(value: 90, child: Text('Last 90 days')),
        DropdownMenuItem(value: 365, child: Text('Last year')),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
