import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// A child's FAVORITES KEEPSAKE — their best photos compiled into a warm,
/// photo-forward PDF that goes home through the export channel (the "book"
/// artifact of the per-child media thread). The lighter, image-led sibling of
/// the Summer Book (`summer_book_pdf.dart`, the WRITTEN history): this one is
/// just the pictures, a few per page, with their date.
///
/// Offline-first: built-in Helvetica only (NEVER `PdfGoogleFonts.*`, which
/// fetches the TTF at print time — see the PdfGoogleFonts gotcha in CLAUDE.md).
/// Helvetica draws only the WinAnsi/Latin-1 subset, so every caption is
/// ASCII-folded first (`_ascii`). The page bytes themselves are a raw print
/// canvas — hardcoded `PdfColor`s are correct here (no screen theme applies);
/// the `_pdf.dart` filename keeps it on the theme-guard raw-canvas allowlist.

/// One photo placed in the keepsake. The bytes are pre-fetched (the caller
/// mints a signed URL + `networkImage`s it); a caption is optional and already
/// scrubbed of any OTHER child's name. [takenAt] is a friendly date string
/// (e.g. "Jun 21") or '' when unknown.
class KeepsakePhoto {
  const KeepsakePhoto({required this.image, this.caption, this.takenAt = ''});

  final pw.ImageProvider image;
  final String? caption;
  final String takenAt;
}

/// Everything the keepsake renderer needs — pure data, no Riverpod / no
/// BuildContext, so it's testable and caches cleanly.
class KeepsakeData {
  const KeepsakeData({
    required this.firstName,
    required this.photos,
    required this.generatedAt,
  });

  /// The child's OWN first name — stays (it's their keepsake). Only OTHER
  /// children's names are scrubbed, upstream, before captions reach here.
  final String firstName;

  /// Favorites first (or the capped took-photos when none are hearted),
  /// already fetched into print images. Order is the order they're laid out.
  final List<KeepsakePhoto> photos;

  final DateTime generatedAt;
}

String _ascii(String s) => s
    .replaceAll('—', '-')
    .replaceAll('–', '-')
    .replaceAll('‘', "'")
    .replaceAll('’', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"')
    .replaceAll('…', '...')
    .replaceAll('•', '-')
    // Anything else outside printable ASCII (emoji, accents Helvetica lacks) →
    // dropped, so a caption never renders as tofu boxes.
    .replaceAll(RegExp(r'[^\x20-\x7E]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Two-word date for a photo: "Jun 21". `intl` isn't pulled in here to keep the
/// renderer dependency-free; the caller can pass a pre-formatted string instead.
const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
];

String keepsakeDateLabel(DateTime? dt) {
  if (dt == null) return '';
  final local = dt.toLocal();
  final m = (local.month >= 1 && local.month <= 12)
      ? _months[local.month - 1]
      : '';
  return m.isEmpty ? '' : '$m ${local.day}';
}

/// Build the keepsake `pw.Document`. A cover page (first name + "A little
/// keepsake" + the date), then the photos three-per-row across the page with
/// their date under each. Letter size, generous margins.
pw.Document buildKeepsakeDoc(KeepsakeData data) {
  final font = pw.Font.helvetica();
  final bold = pw.Font.helveticaBold();
  final firstName = _ascii(data.firstName).isEmpty
      ? 'A child'
      : _ascii(data.firstName);

  final doc =
      pw.Document(
        title: '$firstName — A little keepsake',
        creator: 'Different World',
      )..addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(base: font, bold: bold),
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(48, 56, 48, 48),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 8),
            child: pw.Text(
              'A keepsake  ·  $firstName',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ),
          build: (ctx) => [
            _cover(firstName, data.generatedAt, data.photos.length),
            pw.SizedBox(height: 28),
            _photoFlow(data.photos),
          ],
        ),
      );
  return doc;
}

pw.Widget _cover(String firstName, DateTime generatedAt, int count) {
  final dateLabel = keepsakeDateLabel(generatedAt);
  final year = generatedAt.toLocal().year;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        'A LITTLE KEEPSAKE',
        style: const pw.TextStyle(
          fontSize: 11,
          letterSpacing: 4,
          color: PdfColors.grey600,
        ),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        firstName,
        style: pw.TextStyle(fontSize: 40, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Text(
        dateLabel.isEmpty ? '$year' : '$dateLabel, $year',
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
          count == 1
              ? 'A favorite moment of $firstName, gathered to keep.'
              : 'A handful of favorite moments of $firstName, gathered to keep.',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800),
        ),
      ),
    ],
  );
}

/// The photos, three across, wrapping down the page. Each cell is a square-ish
/// framed image with its date beneath. A `pw.Wrap` inside `MultiPage` reflows
/// across page breaks automatically.
pw.Widget _photoFlow(List<KeepsakePhoto> photos) {
  // Letter content width ≈ 612 - 96 margins = 516pt; three columns with two
  // 12pt gaps → ~164pt each. Fixed so the grid stays even across page breaks.
  const cell = 158.0;
  return pw.Wrap(
    spacing: 12,
    runSpacing: 16,
    children: [for (final p in photos) _photoCell(p, cell)],
  );
}

pw.Widget _photoCell(KeepsakePhoto p, double cell) {
  final caption = p.caption == null ? '' : _ascii(p.caption!);
  return pw.SizedBox(
    width: cell,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.ClipRRect(
          horizontalRadius: 8,
          verticalRadius: 8,
          child: pw.Container(
            width: cell,
            height: cell,
            color: PdfColors.grey200,
            child: pw.Image(p.image, fit: pw.BoxFit.cover),
          ),
        ),
        if (p.takenAt.isNotEmpty || caption.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          if (p.takenAt.isNotEmpty)
            pw.Text(
              p.takenAt,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          if (caption.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1),
              child: pw.Text(
                caption,
                maxLines: 2,
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: PdfColors.grey800,
                ),
              ),
            ),
        ],
      ],
    ),
  );
}

/// Render the keepsake to bytes — handed to the export pipeline
/// (`ExportActions.createAndStore`), exactly like the progress report.
Future<Uint8List> renderKeepsakeBytes(KeepsakeData data) =>
    buildKeepsakeDoc(data).save();
