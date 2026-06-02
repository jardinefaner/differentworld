// The per-vehicle guided-photo editor (docs/VISION.md vehicle tangent). A
// render test over a fake vehicle: both sections + the default shots show,
// and the empty-cabin check-in shot is locked. The save LOGIC (withPhotoShots)
// is covered by vehicle_photo_shots_test.dart.

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/vehicles/vehicle_photo_shots_edit_screen.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fakeVehicle = Vehicle(
    id: 'v1',
    spaceId: 's1',
    name: 'Big White Van',
    capabilities: '{}', // no custom shots → defaults
    createdAt: '2026-01-01T00:00:00Z',
    updatedAt: '2026-01-01T00:00:00Z',
  );

  Widget harness() => ProviderScope(
    overrides: [
      vehicleByIdProvider(
        'v1',
      ).overrideWith((ref) => Stream<Vehicle?>.value(fakeVehicle)),
    ],
    child: const MaterialApp(
      home: VehiclePhotoShotsEditScreen(vehicleId: 'v1'),
    ),
  );

  // Tall viewport so the lazy ListView builds BOTH sections (check-out +
  // check-in) — otherwise the second section is below the fold + not built.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('shows both kinds + default shots; empty-cabin is locked', (
    tester,
  ) async {
    tall(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Check-out'), findsOneWidget);
    expect(find.text('Check-in'), findsOneWidget);

    // A default check-out shot + the safety-anchor check-in shot render.
    expect(find.text('Front of the vehicle'), findsOneWidget);
    expect(find.text('Empty cabin — every child out'), findsOneWidget);

    // The empty-cabin shot is locked (a lock icon, no remove handle).
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    // Both sections offer an "Add a shot" affordance.
    expect(find.widgetWithText(TextButton, 'Add a shot'), findsNWidgets(2));
  });

  testWidgets('removing a shot drops it from the list', (tester) async {
    tall(tester);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Front of the vehicle'), findsOneWidget);
    // The first remove (close) icon belongs to the first check-out shot
    // (Front — not locked, so it has a remove button).
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('Front of the vehicle'), findsNothing);
  });
}
