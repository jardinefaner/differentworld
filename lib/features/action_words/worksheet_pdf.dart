import 'dart:typed_data';

import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Printable activity worksheets for the curriculum. One bordered box per
/// activity — the prompt up top, a generous blank space below to draw or
/// write. Uses PDF's built-in Helvetica (`pw.ThemeData.base()`) so it builds
/// fully OFFLINE (the `PdfGoogleFonts.*` network-fetch trap is avoided).
/// Note: emoji glyphs don't render in Helvetica, so the world's identity is
/// carried by its color (an underline), not its emoji.

/// Map the curly/dash/arrow punctuation the curriculum prose uses into the
/// Latin-1 subset Helvetica can actually draw — otherwise those glyphs print
/// blank. (No bundled-TTF needed; the content is plain text.)
String _ascii(String s) => s
    .replaceAll('—', '-') // em dash
    .replaceAll('–', '-') // en dash
    .replaceAll('‘', "'") // left single quote
    .replaceAll('’', "'") // right single quote / apostrophe
    .replaceAll('“', '"') // left double quote
    .replaceAll('”', '"') // right double quote
    .replaceAll('→', '->') // right arrow
    .replaceAll('…', '...') // ellipsis
    .replaceAll(' ', ' '); // non-breaking space

pw.Document buildWorksheetsDoc(
  List<CurriculumWorld> worlds, {
  required String heading,
}) {
  final doc = pw.Document(title: heading, creator: 'Different World')
    ..addPage(
      pw.MultiPage(
        theme: pw.ThemeData.base(),
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(40, 44, 40, 40),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Different World  ·  page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
        build: (ctx) => [
          pw.Text(
            _ascii(heading),
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            _ascii(
              'Watch → Talk → Do. The video is the spark; the worksheet is '
              'the fire.',
            ),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 16),
          for (final w in worlds) ..._worldSection(w),
        ],
      ),
    );
  return doc;
}

List<pw.Widget> _worldSection(CurriculumWorld w) {
  final color = PdfColor.fromInt(w.color.toARGB32());
  return [
    pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: color, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'WEEK ${w.week}',
            style: const pw.TextStyle(
              fontSize: 9,
              letterSpacing: 2,
              color: PdfColors.grey600,
            ),
          ),
          pw.Text(
            _ascii(w.name),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    ),
    pw.SizedBox(height: 6),
    pw.Text(
      _ascii('“${w.question}”'),
      style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
    ),
    if (w.featuredVerbs.isNotEmpty) ...[
      pw.SizedBox(height: 3),
      pw.Text(
        'Verbs:  ${w.featuredVerbs.map((v) => v.toUpperCase()).join('   ·   ')}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
      ),
    ],
    pw.SizedBox(height: 12),
    for (final a in w.activities) _activityBox(a),
    pw.SizedBox(height: 18),
  ];
}

pw.Widget _activityBox(String activity) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          color: PdfColors.grey100,
          child: pw.Text(
            _ascii(activity),
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
        ),
        // The blank canvas — draw or write here.
        pw.SizedBox(height: 96),
      ],
    ),
  );
}

Future<Uint8List> renderWorksheetsBytes(
  List<CurriculumWorld> worlds, {
  required String heading,
}) {
  return buildWorksheetsDoc(worlds, heading: heading).save();
}

/// Open the print/share sheet for one world's worksheets.
Future<bool> printWorldWorksheets(CurriculumWorld world) {
  return Printing.layoutPdf(
    onLayout: (_) =>
        renderWorksheetsBytes([world], heading: '${world.name} — Worksheets'),
    name: '${world.name} worksheets',
  );
}

/// Open the print/share sheet for the whole 10-week worksheet packet.
Future<bool> printAllWorksheets(List<CurriculumWorld> worlds) {
  return Printing.layoutPdf(
    onLayout: (_) => renderWorksheetsBytes(
      worlds,
      heading: 'If You Built a World — Worksheets',
    ),
    name: 'All worksheets',
  );
}
