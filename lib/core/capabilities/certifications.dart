import 'package:differentworld/core/capabilities/capability_keys.dart';

/// Known staff certifications. Stored as a `List<String>` under
/// [MemberCaps.certifications] in the member's JSONB capabilities
/// blob.
///
/// Each cert may gate specific capability flags. The UI uses
/// [gatesCaps] to disable a switch + show "Requires X cert" when the
/// cert isn't on file.
class Certification {
  const Certification({
    required this.key,
    required this.label,
    required this.description,
    this.gatesCaps = const <String>[],
  });

  /// Stored string in the certifications list.
  final String key;

  /// Human-readable label (e.g. "MAT", "CPR").
  final String label;

  /// Short explanation shown as a chip subtitle.
  final String description;

  /// Capability keys this cert unlocks. A cap with `gatesCaps`
  /// containing 'mat' won't activate unless the member has 'mat'
  /// in their certifications list.
  final List<String> gatesCaps;
}

/// The canonical list of certifications the app recognises. Programs
/// in different states may need different sets eventually — for now
/// this matches a reasonable US-childcare baseline.
abstract final class Certifications {
  static const Certification mat = Certification(
    key: 'mat',
    label: 'MAT',
    description: 'Medication Administration Training',
    gatesCaps: [MemberCaps.canAdministerMedication],
  );

  static const Certification cpr = Certification(
    key: 'cpr',
    label: 'CPR',
    description: 'CPR / Basic Life Support',
  );

  static const Certification firstAid = Certification(
    key: 'first_aid',
    label: 'First Aid',
    description: 'Pediatric First Aid certification',
  );

  static const Certification background = Certification(
    key: 'background',
    label: 'Background',
    description: 'Cleared background check on file',
  );

  static const Certification driver = Certification(
    key: 'driver',
    label: 'Driver',
    description: 'Valid license + insurance for field trips',
    gatesCaps: [MemberCaps.canDrive],
  );

  /// Iteration-friendly all-known set in display order.
  static const List<Certification> all = [
    mat,
    cpr,
    firstAid,
    background,
    driver,
  ];

  /// Find the cert that gates a given capability key, or null.
  /// Used to surface "Requires X cert" subtitles.
  static Certification? gatingCap(String capKey) {
    for (final c in all) {
      if (c.gatesCaps.contains(capKey)) return c;
    }
    return null;
  }
}
