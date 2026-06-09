import 'dart:typed_data';

import 'package:differentworld/features/action_words/summer_book.dart';
import 'package:differentworld/shared/print/pdf_output.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Lays out a child's whole summer as a printable keepsake — the capstone
/// (docs/VISION.md). Built-in Helvetica so it renders fully OFFLINE; an
/// `_ascii` sanitizer maps the curriculum's curly quotes / dashes / arrows
/// into the Latin-1 subset Helvetica can draw. (Photos are a later
/// enrichment — this is the written history: worlds, verbs, milestones,
/// moments.)

String _ascii(String s) => s
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('→', '->')
    .replaceAll('…', '...')
    .replaceAll('•', '-') // bullet → dash (not in Helvetica's WinAnsi)
    .replaceAll(' ', ' ');

pw.Document buildSummerBookDoc(SummerBook book) {
  final doc =
      pw.Document(
        title: '${book.firstName} — A Different World',
        creator: 'Different World',
      )..addPage(
        pw.MultiPage(
          theme: pw.ThemeData.base(),
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 48),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'A Different World  ·  ${_ascii(book.firstName)}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
          build: (ctx) => [
            _cover(book),
            pw.SizedBox(height: 24),
            for (final w in book.weeks) ..._weekSection(w),
            _closing(book),
          ],
        ),
      );
  return doc;
}

pw.Widget _cover(SummerBook book) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'A DIFFERENT WORLD',
        style: const pw.TextStyle(
          fontSize: 11,
          letterSpacing: 4,
          color: PdfColors.grey600,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        _ascii(book.firstName),
        style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold),
      ),
      if (book.title.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Text(
          _ascii(book.title),
          style: pw.TextStyle(
            fontSize: 16,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
      ],
      pw.SizedBox(height: 10),
      pw.Text(
        '${book.days} ${book.days == 1 ? 'day' : 'days'}  ·  '
        '${book.worldsVisited} ${book.worldsVisited == 1 ? 'world' : 'worlds'} visited',
        style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 14),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          _ascii(
            'A summer of becoming — the worlds ${book.firstName} '
            'stepped into, the words they practiced, and the moments the '
            'room noticed along the way.',
          ),
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
        ),
      ),
    ],
  );
}

List<pw.Widget> _weekSection(SummerBookWeek w) {
  final color = PdfColor.fromInt(w.color.toARGB32());
  final header = pw.Container(
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
          _ascii(w.worldName),
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ),
  );

  // A quiet or away week renders as one warm line under the header — never an
  // empty content block (reads as neglect) and never a silently-dropped week
  // (reads as a hole). The world still shows, for continuity.
  if (w.kind != SummerBookWeekKind.full) {
    final note = w.kind == SummerBookWeekKind.away
        ? 'Away this week.'
        : 'A quiet week — here, exploring.';
    return [
      header,
      pw.SizedBox(height: 6),
      pw.Text(
        _ascii(note),
        style: pw.TextStyle(
          fontSize: 11,
          fontStyle: pw.FontStyle.italic,
          color: PdfColors.grey600,
        ),
      ),
      pw.SizedBox(height: 16),
    ];
  }

  return [
    header,
    if (w.question.isNotEmpty) ...[
      pw.SizedBox(height: 6),
      pw.Text(
        _ascii('"${w.question}"'),
        style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic),
      ),
    ],
    if (w.verbs.isNotEmpty) ...[
      pw.SizedBox(height: 6),
      pw.Text(
        _ascii('Practiced:  ${w.verbs.join('  ·  ')}'),
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
    ],
    if (w.milestone.isNotEmpty) _logLine('Milestone', w.milestone),
    if (w.spell.isNotEmpty) _logLine('Spell', w.spell),
    if (w.ally.isNotEmpty) _logLine('Ally', w.ally),
    for (final m in w.moments) ...[
      pw.SizedBox(height: 4),
      pw.Text(_ascii('• $m'), style: const pw.TextStyle(fontSize: 10.5)),
    ],
    pw.SizedBox(height: 20),
  ];
}

pw.Widget _logLine(String label, String value) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 5),
  child: pw.RichText(
    text: pw.TextSpan(
      children: [
        pw.TextSpan(
          text: '$label:  ',
          style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold),
        ),
        pw.TextSpan(
          text: _ascii(value),
          style: const pw.TextStyle(fontSize: 10.5),
        ),
      ],
    ),
  ),
);

pw.Widget _closing(SummerBook book) {
  return pw.Container(
    width: double.infinity,
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          _ascii("That was ${book.firstName}'s summer."),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          _ascii(
            '${book.worldsVisited} worlds, ${book.days} days, and a '
            "whole self that grew. The summer ends; the practice doesn't.",
          ),
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
        ),
      ],
    ),
  );
}

Future<Uint8List> renderSummerBookBytes(SummerBook book) =>
    buildSummerBookDoc(book).save();

/// A child's Summer Book — download on web, print on native.
Future<bool> printSummerBook(SummerBook book) async => emitPdfBytes(
  name: '${book.firstName} — A Different World',
  bytes: await renderSummerBookBytes(book),
);
