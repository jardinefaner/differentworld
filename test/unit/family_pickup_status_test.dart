import 'package:differentworld/features/family/family_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// The family-side pickup status — the "has my child been picked up?" answer.
/// A release wins over the attendance axis; otherwise attendance decides.
void main() {
  group('deriveFamilyPickupState', () {
    test('a release wins → releasedAt with a local time', () {
      final s = deriveFamilyPickupState(
        releasedAtIso: '2026-06-07T20:47:00Z',
        attendanceStatus: 'present',
      );
      expect(s.state, FamilyPickupState.releasedAt);
      expect(s.at, isNotNull);
    });

    test('a release overrides even an absent attendance row', () {
      final s = deriveFamilyPickupState(
        releasedAtIso: '2026-06-07T20:00:00Z',
        attendanceStatus: 'absent',
      );
      expect(s.state, FamilyPickupState.releasedAt);
    });

    test('present / late with no release → here', () {
      expect(
        deriveFamilyPickupState(attendanceStatus: 'present').state,
        FamilyPickupState.here,
      );
      expect(
        deriveFamilyPickupState(attendanceStatus: 'late').state,
        FamilyPickupState.here,
      );
    });

    test('early_pickup → leftEarly', () {
      expect(
        deriveFamilyPickupState(attendanceStatus: 'early_pickup').state,
        FamilyPickupState.leftEarly,
      );
    });

    test('absent / excused → absent', () {
      expect(
        deriveFamilyPickupState(attendanceStatus: 'absent').state,
        FamilyPickupState.absent,
      );
      expect(
        deriveFamilyPickupState(attendanceStatus: 'excused').state,
        FamilyPickupState.absent,
      );
    });

    test('no attendance + no release → unknown (renders nothing)', () {
      expect(deriveFamilyPickupState().state, FamilyPickupState.unknown);
    });
  });
}
