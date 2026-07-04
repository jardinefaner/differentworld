import 'dart:convert';

/// Pure helpers for the vehicle trip headcount (docs/VISION.md vehicle safety
/// ritual). Kept out of the screen so the safety-critical logic is unit-
/// testable without mounting the whole inspection form.

/// Parse the `vehicle_logs.roster` JSON — a list of boarded subject ids.
/// Tolerates null / empty / invalid / non-list → an empty list (so a missing
/// or malformed roster degrades to "no boarding record", never a crash).
List<String> parseRoster(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final decoded = jsonDecode(json);
    return decoded is List ? [for (final e in decoded) e.toString()] : const [];
  } on Object {
    return const [];
  }
}

/// The check-in headcount is cleared only when EVERY boarded child has been
/// tapped off — `boarded ⊆ offBoard`. This is the gate that pairs with the
/// empty-cabin photo to prevent leaving a child in the vehicle.
bool headcountCleared(Set<String> boarded, Set<String> offBoard) =>
    boarded.difference(offBoard).isEmpty;
