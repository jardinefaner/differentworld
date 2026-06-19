import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Print the role deck as cards (docs/VISION.md 2026-06-19 — "collectible…
/// merchandise"). One card per child: a draw-here portrait box (so it prints
/// offline AND doubles as a draw-it activity — color it, cut it out), the role
/// title, the species, and the powers. Six cards a page, Letter.
///
/// Offline-first: built-in Helvetica only (NOT PdfGoogleFonts, which fetches
/// at print time). Helvetica can't render emoji or curly punctuation, so every
/// string is ASCII-folded first.
class RoleCardPrint {
  const RoleCardPrint({
    required this.title,
    required this.species,
    required this.animalLabel,
    required this.powers,
    this.childName,
  });

  final String title;
  final String species;
  final String animalLabel;
  final List<String> powers;
  final String? childName;
}

String _ascii(String s) =>
    s.replaceAll(RegExp(r'[^\x20-\x7E]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();

Future<Uint8List> buildRoleDeckPdf({required List<RoleCardPrint> cards}) async {
  final doc = pw.Document(title: 'Role deck', creator: 'Different World');
  final font = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  const perPage = 6; // 2 columns x 3 rows

  for (var p = 0; p < cards.length; p += perPage) {
    final end = (p + perPage < cards.length) ? p + perPage : cards.length;
    final pageCards = cards.sublist(p, end);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.GridView(
          crossAxisCount: 2,
          childAspectRatio: 0.66,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          children: [for (final c in pageCards) _card(c, font, bold)],
        ),
      ),
    );
  }
  return doc.save();
}

pw.Widget _card(RoleCardPrint c, pw.Font font, pw.Font bold) {
  final animal = _ascii(c.animalLabel);
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(),
      borderRadius: pw.BorderRadius.circular(10),
    ),
    padding: const pw.EdgeInsets.all(10),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // The draw-here portrait — color it in, then cut the card out.
        pw.Expanded(
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 0.5, color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text(
              animal.isEmpty ? 'Draw your role' : 'Draw your $animal',
              style: pw.TextStyle(
                font: font,
                fontSize: 9,
                color: PdfColors.grey500,
              ),
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          _ascii(c.title),
          style: pw.TextStyle(font: bold, fontSize: 12),
          maxLines: 2,
        ),
        if (c.species.trim().isNotEmpty)
          pw.Text(
            _ascii(c.species),
            style: pw.TextStyle(
              font: font,
              fontSize: 8.5,
              color: PdfColors.grey700,
            ),
          ),
        if (c.powers.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              c.powers.map(_ascii).where((s) => s.isNotEmpty).join(', '),
              style: pw.TextStyle(font: font, fontSize: 8.5),
              maxLines: 2,
            ),
          ),
        if (c.childName != null && c.childName!.trim().isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              "${_ascii(c.childName!)}'s card",
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          ),
      ],
    ),
  );
}
