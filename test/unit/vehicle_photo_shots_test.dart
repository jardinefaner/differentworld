// The configurable vehicle guided-photo shot-list (docs/VISION.md vehicle
// tangent). Defaults per kind, per-vehicle config in capabilities JSON, and
// the non-negotiable: check-in always includes the empty-cabin safety shot.

import 'dart:convert';

import 'package:differentworld/features/vehicles/vehicle_photo_shots.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defaults', () {
    test('checkout requires front + odometer', () {
      final shots = defaultShotsFor(VehicleLogKind.checkout);
      final required = shots.where((s) => s.required).map((s) => s.key).toSet();
      expect(required, containsAll(<String>['front', 'odometer']));
    });

    test('check-in requires the empty-cabin safety shot', () {
      final shots = defaultShotsFor(VehicleLogKind.checkin);
      final cabin = shots.firstWhere((s) => s.key == 'empty_cabin');
      expect(cabin.required, isTrue);
    });
  });

  group('shotsFor — config resolution', () {
    test('blank / invalid capabilities → defaults', () {
      expect(shotsFor('', VehicleLogKind.checkout).map((s) => s.key),
          defaultShotsFor(VehicleLogKind.checkout).map((s) => s.key));
      expect(shotsFor('not json', VehicleLogKind.checkout).length,
          defaultShotsFor(VehicleLogKind.checkout).length);
      expect(shotsFor('{}', VehicleLogKind.checkout).length,
          defaultShotsFor(VehicleLogKind.checkout).length);
    });

    test('a per-vehicle config overrides the defaults', () {
      final caps = jsonEncode({
        'photoShots': {
          'checkout': [
            {'key': 'front', 'label': 'Front', 'hint': '', 'required': true},
            {'key': 'tires', 'label': 'Tires', 'hint': 'all four', 'required': false},
          ],
        },
      });
      final shots = shotsFor(caps, VehicleLogKind.checkout);
      expect(shots.map((s) => s.key), ['front', 'tires']);
      expect(shots[1].label, 'Tires');
    });

    test('check-in re-appends the empty-cabin shot even if a config drops it', () {
      final caps = jsonEncode({
        'photoShots': {
          'checkin': [
            {'key': 'odometer', 'label': 'Odometer', 'required': true},
          ],
        },
      });
      final shots = shotsFor(caps, VehicleLogKind.checkin);
      final cabin = shots.where((s) => s.key == 'empty_cabin');
      expect(cabin, hasLength(1), reason: 'safety floor — cannot be configured away');
      expect(cabin.first.required, isTrue);
    });

    test('a config for one kind does not affect the other', () {
      final caps = jsonEncode({
        'photoShots': {
          'checkin': [
            {'key': 'odometer', 'label': 'Odometer', 'required': true},
          ],
        },
      });
      // checkout has no override → defaults
      expect(shotsFor(caps, VehicleLogKind.checkout).length,
          defaultShotsFor(VehicleLogKind.checkout).length);
    });
  });

  group('withPhotoShots — editor round-trip', () {
    test('writes a shot-list that shotsFor reads back, preserving other caps', () {
      const original = '{"canDrive":true}';
      final newShots = [
        const VehiclePhotoShot(
          key: 'front',
          label: 'Front',
          hint: 'whole front',
          required: true,
        ),
        const VehiclePhotoShot(key: 'roof', label: 'Roof', hint: ''),
      ];
      final updated = withPhotoShots(original, VehicleLogKind.checkout, newShots);

      // other capability keys survive
      expect((jsonDecode(updated) as Map)['canDrive'], true);
      // and the shots read back
      final readBack = shotsFor(updated, VehicleLogKind.checkout);
      expect(readBack.map((s) => s.key), ['front', 'roof']);
      expect(readBack.first.required, isTrue);
    });
  });
}
