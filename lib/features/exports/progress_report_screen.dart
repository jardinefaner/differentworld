import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/exports/exports_providers.dart';
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
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        error: (_, _) => ErrorState(
          title: 'Could not load',
          onRetry: () =>
              ref.invalidate(subjectByIdProvider(widget.subjectId)),
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
                    (subjectId: subject.id, kind: EntryKind.observation),
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

          // Quick stat row: tells the director WHAT'S in the report
          // before they generate / send. Saves the "send empty report
          // on a kid who was absent all week" mistake.
          final observationCount = recentObs.length;
          final attendanceDays = summary.present +
              summary.absent +
              summary.late +
              summary.earlyPickup +
              summary.excused;
          final surveysCount = surveys.length;

          return Column(
            children: [
              // Shell reserves the top chrome height.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: ContentHeader(
                  title: 'Progress report',
                  subtitle:
                      '${subject.firstName} ${subject.lastName} · '
                      'last $_windowDays days · $observationCount '
                      'observations · $attendanceDays attendance days · '
                      '$surveysCount surveys',
                  bottomGap: 8,
                ),
              ),
              // Preview takes the lion's share — controls live in a
              // bottom bar so the director SEES what's about to leave
              // their device.
              Expanded(
                child: PdfPreview(
                  build: (format) async {
                    final doc = await buildProgressReportPdf(data);
                    return doc.save();
                  },
                  // Wave 111: allow printing. The bottom bar still
                  // hosts the canonical Share / Email actions, but
                  // a director hitting Cmd+P expects to print the
                  // report — without `allowPrinting: true` the
                  // browser prints the whole Flutter shell with
                  // chrome instead of just the PDF content.
                  allowSharing: false,
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      // Segmented window selector — faster than a
                      // dropdown, all four options visible at once.
                      _WindowSegmented(
                        days: _windowDays,
                        onChanged: (d) =>
                            setState(() => _windowDays = d),
                      ),
                      const SizedBox(height: 10),
                      // Two actions: the canonical "OS share / print"
                      // path AND an explicit "email guardian directly"
                      // shortcut. Both create the audit row server-
                      // side; only one of them actually involves the
                      // family inbox.
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _shareOrPrint(data),
                              icon: const Icon(Icons.ios_share),
                              label: const Text('Share / Print'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () =>
                                  _emailGuardiansDirectly(data),
                              icon: const Icon(Icons.mail_outline),
                              label: const Text('Email guardian'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Generate + persist the PDF, then open the recipient-picker
  /// sheet — same `send-export` Edge Function pipeline used elsewhere,
  /// just initiated inline from the preview screen so the director
  /// doesn't have to bounce out to /exports.
  Future<void> _emailGuardiansDirectly(ProgressReportData data) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigatorCtx = context;
    final actions = ref.read(exportActionsProvider);
    final db = await ref.read(appDatabaseProvider.future);
    await runReported(
      library: 'exports',
      messenger: messenger,
      onError: 'Could not prepare the report for email.',
      action: () async {
        final doc = await buildProgressReportPdf(data);
        final bytes = await doc.save();
        final exportId = await actions.createAndStore(
          templateId: 'progress_report',
          templateVersion: 'v1',
          format: 'pdf',
          bytes: bytes,
          snapshot: {
            'subjectId': data.subject.id,
            'windowDays': data.attendanceSummary.windowDays,
            'generatedAt': data.generatedAt.toIso8601String(),
          },
          subjectId: data.subject.id,
          groupId: data.subject.groupId,
        );
        final row = await db.exportsDao.findById(exportId);
        if (row == null) return;
        if (!navigatorCtx.mounted) return;
        unawaited(navigatorCtx.push('/exports/${row.id}/send', extra: row));
      },
    );
  }

  Future<void> _shareOrPrint(ProgressReportData data) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final actions = ref.read(exportActionsProvider);
    await runReported(
      library: 'exports',
      messenger: messenger,
      onError: 'Could not generate the report.',
      // No onSuccess message — the OS share sheet IS the visible
      // confirmation. A redundant snackbar shows up on top of /
      // after the share sheet and reads as if something else just
      // happened. The "Sent reports" row on the kid's detail
      // screen is the durable confirmation.
      action: () async {
        final doc = await buildProgressReportPdf(data);
        final bytes = await doc.save();
        // 1. Create the audit row + upload bytes to Storage. This
        //    makes the doc permanent in the program's records even
        //    if the user never actually shares.
        final exportId = await actions.createAndStore(
          templateId: 'progress_report',
          templateVersion: 'v1',
          format: 'pdf',
          bytes: bytes,
          snapshot: {
            'subjectId': data.subject.id,
            'windowDays': data.attendanceSummary.windowDays,
            'generatedAt': data.generatedAt.toIso8601String(),
          },
          subjectId: data.subject.id,
          groupId: data.subject.groupId,
        );
        // 2. Hand the local bytes to the share sheet — they go to
        //    AirDrop, email, Save to Files, print, whatever.
        await Printing.sharePdf(
          bytes: bytes,
          filename: 'progress-${data.subject.firstName.toLowerCase()}-'
              '${data.generatedAt.toIso8601String().substring(0, 10)}.pdf',
        );
        // 3. Mark sent with channel = 'manual' — we don't know
        //    where the OS share sheet ended up, but the audit at
        //    least records that the doc *left* the device.
        await actions.markSent(
          exportId: exportId,
          recipients: [
            (
              kind: 'external',
              guardianId: null,
              memberId: null,
              externalLabel: 'Share sheet',
              externalEmail: null,
              channel: 'manual',
            ),
          ],
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

/// Segmented buttons for the time window — all 4 options visible at
/// once, no modal, single tap to switch. Replaces the old
/// [DropdownButtonFormField] which buried the same options behind a
/// menu.
class _WindowSegmented extends StatelessWidget {
  const _WindowSegmented({required this.days, required this.onChanged});

  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 7, label: Text('7d')),
        ButtonSegment(value: 30, label: Text('30d')),
        ButtonSegment(value: 90, label: Text('90d')),
        ButtonSegment(value: 365, label: Text('1y')),
      ],
      selected: {days},
      onSelectionChanged: (s) {
        if (s.isNotEmpty) onChanged(s.first);
      },
      showSelectedIcon: false,
    );
  }
}
