import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One auto-filled fact on the welcome one-pager.
typedef WelcomeFact = ({String label, String value});

/// The built-in PDF Helvetica only has a Latin glyph set — it can't draw
/// em-dashes or curly quotes (the pdf package warns + renders them blank).
/// Curriculum text (world names, the dinner question) routinely has them, so
/// every string that reaches the page goes through this first. Keeps the PDF
/// offline-safe (built-in font, no bundled TTF) without broken glyphs.
String _safe(String s) => s
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('’', "'")
    .replaceAll('‘', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...');

/// Builds the **first-day parent welcome** one-pager (docs/VISION.md — the
/// family's day-one orientation). Three jobs, in order: the big idea (what
/// makes this program different), how to stay connected (the app invite QR),
/// then the practical details.
///
/// Offline-safe by construction: built-in Helvetica (NOT `PdfGoogleFonts`,
/// which downloads at print time — see the gotcha in CLAUDE.md) + the `pdf`
/// package's own QR, so a director can print a stack on a no-signal device.
/// Mostly auto-filled from app data; the caller gathers the fields.
Future<Uint8List> buildWelcomePdf({
  required String programName,
  required String childFirstName,
  required List<WelcomeFact> facts,
  String? welcomeLine,
  String? worldName,
  String? dinnerQuestion,
  String? whatToBring,
  String? contactLine,
  String? inviteUrl,
  String? inviteCode,
  String? inviteFallbackLine,
}) async {
  final doc = pw.Document(
    title: 'Welcome - ${_safe(childFirstName)}',
    creator: 'Different World',
  );
  final font = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final italic = pw.Font.helveticaOblique();
  const teal = PdfColor.fromInt(0xFF0F6E56);
  const amber = PdfColor.fromInt(0xFF854F0B);

  final program = _safe(programName);
  final child = _safe(childFirstName);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(48),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Welcome to $program, $child!',
            style: pw.TextStyle(font: bold, fontSize: 26, color: teal),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            _safe(welcomeLine ??
                'Here, every day your child picks three action words - like '
                    'explore, build, and help - and lives them through play. '
                    'Over the weeks, those choices add up to a story of who '
                    'they are becoming. Not worksheets: play, with intention.'),
            style: pw.TextStyle(font: font, fontSize: 13, lineSpacing: 3),
          ),
          pw.SizedBox(height: 22),
          // The app invite - the anxiety-killer: how they'll see the day.
          // Online → a QR to the family app. Offline → a note instead of a
          // dead QR (an invite minted offline hasn't synced to the server
          // yet, so scanning it would land on "invalid invite"). When there's
          // no invite at all, the whole block is omitted.
          if (inviteUrl != null || inviteFallbackLine != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (inviteUrl != null) ...[
                    pw.BarcodeWidget(
                      data: inviteUrl,
                      barcode: pw.Barcode.qrCode(),
                      width: 92,
                      height: 92,
                    ),
                    pw.SizedBox(width: 14),
                  ],
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'See $child at school, live',
                          style: pw.TextStyle(
                              font: bold, fontSize: 15, color: teal),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          inviteUrl != null
                              ? "Scan to join the family app: today's photo, "
                                  'the words they chose, when they are checked '
                                  'in and picked up, and a direct line to their '
                                  'teacher.'
                              : _safe(inviteFallbackLine!),
                          style: pw.TextStyle(
                              font: font, fontSize: 11, lineSpacing: 2),
                        ),
                        if (inviteCode != null) ...[
                          pw.SizedBox(height: 6),
                          pw.Text(
                            'Code: ${_safe(inviteCode)}',
                            style: pw.TextStyle(font: bold, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 18),
          ],
          if (worldName != null) ...[
            pw.Text(
              "THIS WEEK'S WORLD",
              style: pw.TextStyle(font: bold, fontSize: 10, color: amber),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              _safe(worldName),
              style: pw.TextStyle(font: bold, fontSize: 16, color: amber),
            ),
            if (dinnerQuestion != null) ...[
              pw.SizedBox(height: 3),
              pw.Text(
                'Ask at dinner: "${_safe(dinnerQuestion)}"',
                style: pw.TextStyle(font: italic, fontSize: 12, color: amber),
              ),
            ],
            pw.SizedBox(height: 18),
          ],
          pw.Text(
            'THE PRACTICAL STUFF',
            style:
                pw.TextStyle(font: bold, fontSize: 10, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 8),
          for (var i = 0; i < facts.length; i += 2)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                children: [
                  _factCell(font, bold, facts[i]),
                  if (i + 1 < facts.length)
                    _factCell(font, bold, facts[i + 1])
                  else
                    pw.Expanded(child: pw.SizedBox()),
                ],
              ),
            ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Please bring: ${_safe(whatToBring ?? 'a water bottle and a snack')}. '
            'And please confirm with us: allergies, your pickup list, and '
            'photo consent.',
            style:
                pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
          ),
          pw.Spacer(),
          pw.Divider(color: PdfColors.grey300),
          pw.Text(
            _safe(contactLine ??
                'Questions any time - message your teacher right in the app.'),
            style:
                pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _factCell(pw.Font font, pw.Font bold, WelcomeFact fact) => pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            _safe(fact.label),
            style:
                pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
          ),
          pw.Text(_safe(fact.value),
              style: pw.TextStyle(font: bold, fontSize: 13)),
        ],
      ),
    );
