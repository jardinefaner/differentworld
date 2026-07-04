import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One row of the incident report: the parsed incident + the child's
/// resolved name (resolved by the caller so the renderer stays pure —
/// no Riverpod, no BuildContext, testable + cacheable).
class IncidentReportEntry {
  IncidentReportEntry({required this.incident, required this.childName});

  final Incident incident;
  final String childName;
}

/// Render data for the incident report PDF — a compliance record a
/// director can hand to licensing.
class IncidentReportData {
  IncidentReportData({
    required this.entries,
    required this.spaceName,
    required this.title,
    required this.generatedAt,
  });

  final List<IncidentReportEntry> entries;
  final String? spaceName;

  /// "Incident report" or "Incidents needing follow-up", depending on the
  /// filter that was active when the export fired.
  final String title;
  final DateTime generatedAt;

  int get notifiedCount =>
      entries.where((e) => e.incident.parentNotified).length;
}

/// Build the `pw.Document`. Uses PDF's built-in Helvetica
/// (`pw.ThemeData.base()`) — no network font fetch, so it works fully
/// offline (the `PdfGoogleFonts.*` trap is deliberately avoided).
Future<pw.Document> buildIncidentReportPdf(IncidentReportData data) async {
  final doc = pw.Document();
  final theme = pw.ThemeData.base();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 48),
      theme: theme,
      header: (ctx) => _header(data),
      footer: (ctx) => _footer(ctx, data),
      build: (ctx) => [
        _summary(data),
        pw.SizedBox(height: 16),
        if (data.entries.isEmpty)
          pw.Text(
            'No incidents in this report.',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          )
        else
          for (final e in data.entries) ...[
            _incidentBlock(e),
            pw.SizedBox(height: 10),
          ],
      ],
    ),
  );
  return doc;
}

pw.Widget _header(IncidentReportData data) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
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
          data.title,
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

pw.Widget _footer(pw.Context ctx, IncidentReportData data) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(top: 8),
    decoration: const pw.BoxDecoration(
      border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Generated ${dateKey(data.generatedAt)} ${timeOfDay(data.generatedAt)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
        pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
        ),
      ],
    ),
  );
}

pw.Widget _summary(IncidentReportData data) {
  final n = data.entries.length;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        data.title,
        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        n == 1
            ? '1 incident · ${data.notifiedCount} with family notified'
            : '$n incidents · ${data.notifiedCount} with family notified',
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
    ],
  );
}

pw.Widget _incidentBlock(IncidentReportEntry e) {
  final inc = e.incident;
  final when = DateTime.tryParse(inc.recordedAt)?.toLocal();
  final whenLabel = when == null ? '' : '${dateKey(when)} ${timeOfDay(when)}';
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(
        left: pw.BorderSide(color: PdfColors.grey400, width: 2),
      ),
    ),
    padding: const pw.EdgeInsets.only(left: 10, bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${e.childName}  ·  ${inc.type.label}',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              whenLabel,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        if (inc.narrative.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(inc.narrative, style: const pw.TextStyle(fontSize: 11)),
        ],
        if (inc.actionTaken != null && inc.actionTaken!.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            'Action taken: ${inc.actionTaken}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
        ],
        pw.SizedBox(height: 3),
        pw.Text(
          inc.parentNotified ? 'Family notified' : 'Family NOT yet notified',
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: inc.parentNotified ? PdfColors.green800 : PdfColors.red800,
          ),
        ),
      ],
    ),
  );
}
