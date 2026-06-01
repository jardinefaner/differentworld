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

/// "12" not "12.0"; "1.5" stays "1.5".
String formatSupplyNumber(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();
