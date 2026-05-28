import 'dart:typed_data';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/vehicles/vehicle_deep_link.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart'
    show VehicleLogKind;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Builds a printable PDF that carries a QR code for [vehicle]'s
/// checkout flow.
///
/// The QR encodes the **HTTPS** form
/// (`https://differentworld.app/v/<id>/checkout`) — Wave 165.2.
/// Earlier prints used the custom-scheme form, which several Android
/// camera apps treat as plain text and fall through to a browser
/// "we can't find that page." The HTTPS form lands on the static
/// fallback page hosted at differentworld.app/404.html, which then
/// JS-redirects into the custom scheme (`differentworld://v/...`) so
/// the OS routes into the installed app. If the app isn't installed,
/// the page surfaces an explicit "Open in app" affordance instead of
/// a confusing browser 404.
///
/// The in-app scanner ([VehicleDeepLink.tryParse]) accepts both
/// forms, so QRs printed under either format still scan correctly
/// from inside the app.
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

  // Wave 170: encode the github.io URL while DNS for
  // differentworld.app is unresolved. The OS camera scans this
  // cleanly and the static page on GitHub Pages handles the
  // deep-link handoff. Swap back to `httpsUri` once DNS lands.
  final uri = VehicleDeepLink.pagesUri(
    vehicleId: vehicle.id,
    kind: kind,
  );

  final font = await PdfGoogleFonts.interMedium();
  final fontBold = await PdfGoogleFonts.interBold();
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
/// Wraps [buildVehicleCheckoutQrPdf] + `Printing.layoutPdf` so the
/// caller is one tap away from a finished sticker. On desktop platforms
/// this routes to the OS print dialog; on mobile it opens the
/// system share / print sheet.
Future<void> printVehicleCheckoutQr({
  required Vehicle vehicle,
  String kind = VehicleLogKind.checkout,
}) {
  return Printing.layoutPdf(
    onLayout: (_) => buildVehicleCheckoutQrPdf(vehicle: vehicle, kind: kind),
    name: '${vehicle.name} — Check ${kind == VehicleLogKind.checkout ? 'out' : 'in'} QR',
  );
}
