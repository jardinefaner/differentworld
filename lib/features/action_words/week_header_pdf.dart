import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Shared week/world section header for the action-words PDFs (summer book,
/// worksheets): a 'WEEK n' eyebrow + the world name over an accent underline.
/// Print canvas — hardcoded PdfColors are the norm here (allowlisted via the
/// `_pdf.dart` suffix). Pass [name] already sanitized (each builder's
/// `_ascii`).
pw.Widget weekHeaderPdf({
  required PdfColor color,
  required int week,
  required String name,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: color, width: 3)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'WEEK $week',
          style: const pw.TextStyle(
            fontSize: 9,
            letterSpacing: 2,
            color: PdfColors.grey600,
          ),
        ),
        pw.Text(
          name,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );
}
