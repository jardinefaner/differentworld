/// How full a room is, and whether that is allowed (docs/ROOMS.md).
///
/// The single most regulated number in childcare, and the app could not
/// answer it: nothing tracked licensed capacity or the staffing ratio, so a
/// room holding fourteen four-year-olds with one adult looked exactly like a
/// room holding six with two.
///
/// **Honest about what it knows.** The app has no staff clock-in, so
/// `staffAssigned` is who is ASSIGNED to the room, not who is standing in
/// it. That is a weaker claim than a ratio inspection would make, and the UI
/// says "assigned" rather than "present" so nobody mistakes one for the
/// other. Adding staff presence later tightens this without changing shape.
library;

/// Whether a room is within its limits, and by how much.
class RoomLoad {
  const RoomLoad({
    required this.childrenPresent,
    required this.staffAssigned,
    this.licensedCapacity,
    this.ratioChildrenPerAdult,
  });

  final int childrenPresent;
  final int staffAssigned;

  /// Null = not set for this room. Never read as "unlimited".
  final int? licensedCapacity;
  final int? ratioChildrenPerAdult;

  bool get hasCapacityRule => (licensedCapacity ?? 0) > 0;
  bool get hasRatioRule => (ratioChildrenPerAdult ?? 0) > 0;

  /// Nothing to check against — the room has no numbers on file.
  bool get unchecked => !hasCapacityRule && !hasRatioRule;

  /// More children in the room than it may legally hold.
  bool get overCapacity =>
      hasCapacityRule && childrenPresent > licensedCapacity!;

  /// How many adults this many children require.
  ///
  /// Ceiling division: 13 children at 1:8 needs two adults, not 1.6. Zero
  /// children needs zero adults — an empty room is not understaffed.
  int? get staffRequired {
    if (!hasRatioRule) return null;
    if (childrenPresent <= 0) return 0;
    return (childrenPresent + ratioChildrenPerAdult! - 1) ~/
        ratioChildrenPerAdult!;
  }

  /// Fewer adults than the ratio requires.
  bool get understaffed {
    final needed = staffRequired;
    return needed != null && staffAssigned < needed;
  }

  /// How many more adults are needed, or null when the ratio is met / unset.
  int? get staffShort {
    final needed = staffRequired;
    if (needed == null || staffAssigned >= needed) return null;
    return needed - staffAssigned;
  }

  /// How many more children the room could take before breaching EITHER
  /// rule — the number a director actually wants when the phone rings and
  /// somebody asks if there is a space. Null when nothing is set.
  int? get roomFor {
    final limits = <int>[
      if (hasCapacityRule) licensedCapacity! - childrenPresent,
      if (hasRatioRule)
        staffAssigned * ratioChildrenPerAdult! - childrenPresent,
    ];
    if (limits.isEmpty) return null;
    final smallest = limits.reduce((a, b) => a < b ? a : b);
    return smallest < 0 ? 0 : smallest;
  }

  bool get breached => overCapacity || understaffed;
}
