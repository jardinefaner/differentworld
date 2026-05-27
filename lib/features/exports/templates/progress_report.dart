import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:differentworld/features/surveys/surveys_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Render data for a per-kid progress report PDF. Pure data — no
/// Riverpod, no BuildContext, so it's testable + caches well.
class ProgressReportData {
  ProgressReportData({
    required this.subject,
    required this.spaceName,
    required this.groupName,
    required this.observations,
    required this.attendanceSummary,
    required this.surveySummaries,
    required this.generatedAt,
  });

  final Subject subject;
  final String? spaceName;
  final String? groupName;
  final List<Entry> observations;
  final AttendanceSummary attendanceSummary;
  final List<SurveySummary> surveySummaries;
  final DateTime generatedAt;
}

/// Rolled-up attendance counts for the report window. Computed in the
/// provider; the renderer just lays them out.
class AttendanceSummary {
  AttendanceSummary({
    required this.windowDays,
    required this.present,
    required this.absent,
    required this.late,
    required this.earlyPickup,
    required this.excused,
  });

  final int windowDays;
  final int present;
  final int absent;
  final int late;
  final int earlyPickup;
  final int excused;

  int get totalRecorded =>
      present + absent + late + earlyPickup + excused;
}

/// One survey, summarized for the report. The renderer shows the
/// kid's answers grouped under each question.
class SurveySummary {
  SurveySummary({required this.template, required this.answers});

  final SurveyTemplate template;
  final SurveyAnswers answers;
}

/// Build the actual `pw.Document`. The `printing` package then
/// either renders it to a layout for share / save, or pipes it
/// to the platform print dialog.
Future<pw.Document> buildProgressReportPdf(ProgressReportData data) async {
  final doc = pw.Document();
  final theme = await _theme();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
      theme: theme,
      header: (ctx) => _header(data),
      footer: (ctx) => _footer(ctx, data),
      build: (ctx) => [
        _identitySection(data),
        pw.SizedBox(height: 16),
        _attendanceSection(data),
        pw.SizedBox(height: 16),
        if (data.surveySummaries.isNotEmpty) ...[
          _surveysSection(data),
          pw.SizedBox(height: 16),
        ],
        _observationsSection(data),
      ],
    ),
  );

  return doc;
}

Future<pw.ThemeData> _theme() async {
  // Using PDF's default Helvetica — bundling a custom font would
  // require an asset roundtrip; not worth it for v1. The default
  // renders cleanly on every PDF viewer.
  return pw.ThemeData.base();
}

pw.Widget _header(ProgressReportData data) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: PdfColors.grey300),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          data.spaceName ?? 'Program',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          'Progress report',
          style: pw.TextStyle(
            fontSize: 12,
            color: PdfColors.grey700,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _footer(pw.Context ctx, ProgressReportData data) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        top: pw.BorderSide(color: PdfColors.grey300),
      ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated ${_formatDate(data.generatedAt)}',
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey600,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _identitySection(ProgressReportData data) {
  final subject = data.subject;
  final fullName = '${subject.firstName} ${subject.lastName}'.trim();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        fullName,
        style: pw.TextStyle(
          fontSize: 22,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        [
          if (subject.dob != null) 'DOB: ${subject.dob}',
          if (data.groupName != null) 'Classroom: ${data.groupName}',
        ].join('   ·   '),
        style: const pw.TextStyle(
          fontSize: 11,
          color: PdfColors.grey700,
        ),
      ),
    ],
  );
}

pw.Widget _attendanceSection(ProgressReportData data) {
  final s = data.attendanceSummary;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Attendance (last ${s.windowDays} days)'),
      pw.SizedBox(height: 6),
      pw.Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _statChip('Present', s.present),
          _statChip('Late', s.late),
          _statChip('Absent', s.absent),
          _statChip('Early pickup', s.earlyPickup),
          _statChip('Excused', s.excused),
        ],
      ),
      if (s.totalRecorded == 0)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'No attendance recorded in this window.',
            style: const pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey600,
            ),
          ),
        ),
    ],
  );
}

pw.Widget _statChip(String label, int value) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          '$value',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _surveysSection(ProgressReportData data) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Surveys'),
      pw.SizedBox(height: 6),
      for (final s in data.surveySummaries) ...[
        pw.Text(
          '${s.template.title} · ${s.template.year}',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        for (final q in s.template.scored) _surveyQA(q, s.answers),
        pw.SizedBox(height: 8),
      ],
    ],
  );
}

pw.Widget _surveyQA(SurveyQuestion q, SurveyAnswers a) {
  final answer = switch (q.kind) {
    SurveyQuestionKind.agree3 => switch (a.agree3(q.key)) {
        0 => 'No',
        1 => 'Maybe',
        2 => 'Yes',
        _ => '—',
      },
    // Wave 167: 5-point scales — render as "score/5 · label" so the
    // PDF reader sees both the numeric value and the meaning. agree5
    // and likeMe5 share the same data shape but use different label
    // sets per the editorial intent.
    SurveyQuestionKind.agree5 => switch (a.scale5(q.key)) {
        0 => '1/5 · Strongly disagree',
        1 => '2/5 · Disagree',
        2 => '3/5 · Kind of agree',
        3 => '4/5 · Agree',
        4 => '5/5 · Strongly agree',
        _ => '—',
      },
    SurveyQuestionKind.likeMe5 => switch (a.scale5(q.key)) {
        0 => '1/5 · Not like me',
        1 => '2/5 · A little like me',
        2 => '3/5 · Somewhat like me',
        3 => '4/5 · Mostly like me',
        4 => '5/5 · Exactly like me',
        _ => '—',
      },
    SurveyQuestionKind.multiselect => () {
        final ks = a.multiselect(q.key);
        if (ks.isEmpty) return '—';
        return ks.map((k) {
          final opt = q.options.firstWhere(
            (o) => o.key == k,
            orElse: () => SurveyOption(key: k, label: k, labelEs: k),
          );
          return opt.label;
        }).join('; ');
      }(),
    SurveyQuestionKind.text => a.text(q.key).isEmpty ? '—' : a.text(q.key),
  };
  return pw.Padding(
    padding: const pw.EdgeInsets.only(left: 8, top: 2, bottom: 2),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '${q.prompt}  ',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.TextSpan(
            text: answer,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _observationsSection(ProgressReportData data) {
  if (data.observations.isEmpty) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionHeading('Observations'),
        pw.SizedBox(height: 4),
        pw.Text(
          'No observations recorded.',
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      _sectionHeading('Observations'),
      pw.SizedBox(height: 6),
      for (final e in data.observations) ...[
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.grey300, width: 2),
            ),
          ),
          padding: const pw.EdgeInsets.only(left: 8, bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _formatDateTime(DateTime.tryParse(e.recordedAt)),
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                e.body ?? '(no text)',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
      ],
    ],
  );
}

pw.Widget _sectionHeading(String label) {
  return pw.Text(
    label.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 10,
      fontWeight: pw.FontWeight.bold,
      letterSpacing: 1.2,
      color: PdfColors.grey800,
    ),
  );
}

String _formatDate(DateTime dt) => dateKey(dt);

String _formatDateTime(DateTime? dt) =>
    dt == null ? '' : '${dateKey(dt)} ${timeOfDay(dt)}';
