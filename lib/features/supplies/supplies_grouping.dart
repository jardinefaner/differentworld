import 'package:differentworld/core/db/app_database.dart';

/// Pure view-logic for the supplies list (docs/SUPPLIES.md), extracted so
/// it's unit-testable without a viewer/DB harness.

/// The display category — "Uncategorized" when the supply has none.
String supplyCategoryLabel(Supply s) {
  final c = s.category?.trim();
  return (c == null || c.isEmpty) ? 'Uncategorized' : c;
}

/// A supply is "low" when it has BOTH a quantity and a threshold, and the
/// quantity is at or below the threshold. No threshold ⇒ never low.
bool isLowStock(Supply s) =>
    s.quantity != null &&
    s.lowStockThreshold != null &&
    s.quantity! <= s.lowStockThreshold!;

/// Flatten supplies into list rows: a `String` category header followed by
/// the `Supply` rows in that category. Assumes [supplies] is already
/// ordered by category then name (the DAO's order), so same-category rows
/// are adjacent — a header is emitted whenever the category changes.
List<Object> groupSuppliesByCategory(List<Supply> supplies) {
  final rows = <Object>[];
  String? lastCat;
  for (final s in supplies) {
    final cat = supplyCategoryLabel(s);
    if (cat != lastCat) {
      rows.add(cat);
      lastCat = cat;
    }
    rows.add(s);
  }
  return rows;
}

/// The location label for a supply: the real Location's name (resolved via
/// [locationNames] keyed by location id) if linked, else the free-text
/// `location`, else "No location set".
String supplyLocationLabel(Supply s, Map<String, String> locationNames) {
  final byId = s.locationId == null ? null : locationNames[s.locationId];
  if (byId != null && byId.trim().isNotEmpty) return byId;
  final free = s.location?.trim();
  return (free == null || free.isEmpty) ? 'No location set' : free;
}

/// Flatten supplies into rows grouped by LOCATION (header `String` then its
/// supplies). Unlike category, the DAO order isn't location-sorted, so this
/// buckets first, then orders headers alphabetically with "No location set"
/// pinned last.
List<Object> groupSuppliesByLocation(
  List<Supply> supplies,
  Map<String, String> locationNames,
) {
  const noLoc = 'No location set';
  final buckets = <String, List<Supply>>{};
  for (final s in supplies) {
    (buckets[supplyLocationLabel(s, locationNames)] ??= <Supply>[]).add(s);
  }
  final keys = buckets.keys.toList()
    ..sort((a, b) {
      if (a == noLoc) return 1;
      if (b == noLoc) return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  final rows = <Object>[];
  for (final k in keys) {
    rows.add(k);
    final items = buckets[k]!..sort((a, b) => a.name.compareTo(b.name));
    rows.addAll(items);
  }
  return rows;
}

/// Just the low-stock supplies (the "Running low" restock list).
List<Supply> lowStockSupplies(List<Supply> supplies) =>
    supplies.where(isLowStock).toList();

/// "12" not "12.0"; "1.5" stays "1.5".
String formatSupplyNumber(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
