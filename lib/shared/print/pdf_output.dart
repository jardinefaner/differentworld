import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

String _safeName(String name) => name
    .trim()
    .replaceAll(RegExp('[^a-zA-Z0-9 _-]'), '')
    .replaceAll(RegExp(r'\s+'), '-');

/// The single seam every PDF goes out through.
///
/// - **Web** → DOWNLOAD the file (`sharePdf`). A browser print dialog is clunky
///   and teachers prep offline — they want the .pdf on disk to print later.
/// - **Native** → the OS print dialog (`layoutPdf`), which also carries its own
///   copies field.
Future<bool> emitPdfBytes({required String name, required Uint8List bytes}) {
  if (kIsWeb) {
    return Printing.sharePdf(bytes: bytes, filename: '${_safeName(name)}.pdf');
  }
  return Printing.layoutPdf(onLayout: (_) => bytes, name: name);
}

/// Build a PDF from a [pages] closure and emit it (web download / native
/// print). [copies] re-runs the closure that many times so "how many to print"
/// bakes into the file itself — essential on the web download path, where the
/// downloaded PDF has no copies dialog until it's opened. The closure MUST
/// return fresh `pw.Page` objects each call (a page can't be added twice).
Future<bool> emitPdf({
  required String name,
  required List<pw.Page> Function() pages,
  int copies = 1,
}) async {
  final doc = pw.Document(creator: 'Different World');
  final n = copies < 1 ? 1 : copies;
  for (var c = 0; c < n; c++) {
    pages().forEach(doc.addPage);
  }
  return emitPdfBytes(name: name, bytes: await doc.save());
}
