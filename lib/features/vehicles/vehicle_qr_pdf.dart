import 'dart:typed_data';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/vehicles/vehicle_deep_link.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart'
    show VehicleLogKind;
import 'package:differentworld/shared/print/pdf_output.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds a printable PDF that carries a QR code for [vehicle]'s
/// checkout flow.
///
/// The QR encodes the **custom-scheme** form
/// (`differentworld://v/<id>/checkout`) — Wave 171. Vehicle QRs are
/// only ever scanned by staff, who always have the app installed, so
/// the custom scheme is the right call: a scan opens the app
/// *directly*, with no browser hop and no hosting / DNS dependency.
///
/// This reverses the Wave 165.2 → 170 detour through an HTTPS URL +
/// GitHub Pages fallback page. That detour existed to gracefully
/// handle "app not installed," but for a staff-scanned vehicle QR
/// that case never happens — and the HTTPS path always flashed a web
/// page first (the OS opens `https://` in the browser; an *unverified*
/// App Link can't intercept it). The custom scheme skips all of that.
/// The no-app fallback still matters for *invite* QRs (a guardian may
/// not have the app yet), so those keep the HTTPS / App-Links path —
/// see CLAUDE.md "QR deep links: vehicle = scheme, invite = https".
///
/// Backward-compatible: the in-app scanner ([VehicleDeepLink.tryParse])
/// and the github.io intent filters still accept the apex + project-
/// page HTTPS forms, so vehicle QRs printed under Waves 165–170 keep
/// working — old stickers route via the web page, new stickers open
/// straight into the app.
///
/// Layout (US Letter, portrait): big vehicle name centered, the QR
/// square below it, instructions at the bottom. Sized so a director
/// can print → laminate → tape to the dashboard.
Future<Uint8List> buildVehicleCheckoutQrPdf({
  required Vehicle vehicle,
  String kind = VehicleLogKind.checkout,
}) async {
  final doc = pw.Document(
    title: '${vehicle.name} — Check ${kind == VehicleLogKind.checkout ? 'out' : 'in'} QR',
    creator: 'Different World',
  );

  // Wave 171: encode the custom scheme so a staff scan opens the app
  // directly — no browser, no GitHub Pages hop, no DNS dependency.
  // Do NOT swap this back to httpsUri/pagesUri: an https QR always
  // opens the browser first until App Links are verified, which is the
  // web flash we're removing here. (Invite QRs keep the https path for
  // the genuine no-app-installed case.)
  final uri = VehicleDeepLink.customSchemeUri(
    vehicleId: vehicle.id,
    kind: kind,
  );

  // Built-in standard PDF fonts — NOT PdfGoogleFonts, which downloads the
  // TTF from Google's CDN at generation time and breaks offline-first (a
  // director printing a QR sticker on a captive-portal / no-signal device
  // gets a hung/failed PDF). Helvetica is embedded in every PDF reader:
  // zero network, zero asset. See the "PdfGoogleFonts.*() downloads at
  // print time" gotcha in CLAUDE.md.
  final font = pw.Font.helvetica();
  final fontBold = pw.Font.helveticaBold();
  final plate = vehicle.licensePlate;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(48),
      build: (context) {
        return pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              vehicle.name,
              style: pw.TextStyle(font: fontBold, fontSize: 36),
              textAlign: pw.TextAlign.center,
            ),
            if (plate != null && plate.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(
                  'Plate: $plate',
                  style: pw.TextStyle(font: font, fontSize: 14),
                ),
              ),
            pw.SizedBox(height: 36),
            pw.BarcodeWidget(
              data: uri.toString(),
              barcode: pw.Barcode.qrCode(),
              width: 320,
              height: 320,
            ),
            pw.SizedBox(height: 36),
            pw.Text(
              kind == VehicleLogKind.checkout
                  ? 'Scan to check out'
                  : 'Scan to check in',
              style: pw.TextStyle(font: fontBold, fontSize: 22),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Open the camera and point it at the code.\n'
              'The Different World app will open this vehicle.',
              style: pw.TextStyle(
                font: font,
                fontSize: 12,
                color: PdfColors.grey700,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.Spacer(),
            pw.Text(
              uri.toString(),
              style: pw.TextStyle(
                font: font,
                fontSize: 8,
                color: PdfColors.grey500,
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

/// Opens the platform print dialog for [vehicle]'s checkout QR.
///
/// Wraps [buildVehicleCheckoutQrPdf] + `emitPdfBytes` so the caller is one tap
/// away from a finished sticker — downloaded on web, OS print dialog on native.
Future<void> printVehicleCheckoutQr({
  required Vehicle vehicle,
  String kind = VehicleLogKind.checkout,
}) async {
  final bytes = await buildVehicleCheckoutQrPdf(vehicle: vehicle, kind: kind);
  await emitPdfBytes(
    name: '${vehicle.name} — Check '
        '${kind == VehicleLogKind.checkout ? 'out' : 'in'} QR',
    bytes: bytes,
  );
}
