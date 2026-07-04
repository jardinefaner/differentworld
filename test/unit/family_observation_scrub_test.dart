import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:flutter_test/flutter_test.dart';

/// The family-observation scrub is enforced SERVER-SIDE (migration
/// 20260620000001's RPC), so its SQL can't be unit-tested from here. But the
/// load-bearing invariant — that it is privacy-safe BY DEFAULT — is the same
/// `coalesce(cap, true)` on both sides, and the Dart cap-read is the testable
/// twin of the SQL gate. If this default ever flips, raw observation bodies
/// (which can name other children) would reach guardians.
void main() {
  group('scrub_family_observations capability', () {
    test('defaults to ON (scrub) when the cap is absent — privacy-safe', () {
      const caps = Capabilities.empty();
      expect(
        caps.getBool(SpaceCaps.scrubFamilyObservations, fallback: true),
        isTrue,
      );
    });

    test('only an explicit false disables the scrub', () {
      final off = const Capabilities.empty().setting(
        SpaceCaps.scrubFamilyObservations,
        false,
      );
      expect(
        off.getBool(SpaceCaps.scrubFamilyObservations, fallback: true),
        isFalse,
      );

      final on = const Capabilities.empty().setting(
        SpaceCaps.scrubFamilyObservations,
        true,
      );
      expect(
        on.getBool(SpaceCaps.scrubFamilyObservations, fallback: true),
        isTrue,
      );
    });
  });
}
