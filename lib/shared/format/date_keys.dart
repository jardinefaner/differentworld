// Canonical `YYYY-MM-DD` and `HH:MM` formatters.
//
// Replaces the hand-rolled `.padLeft(2, '0')` pads that were
// scattered across schedule / attendance / today / family /
// observation surfaces. Use these for stored keys, query
// parameters, and machine-readable display. For user-facing dates
// (long-form / locale-aware), use `package:intl/intl.dart`
// formatters like `DateFormat.yMMMd()` instead.

/// `YYYY-MM-DD` from the local-time components of [dt].
///
/// The format matches `LOCAL DATE` semantics in our schema (e.g.
/// `attendance_records.attendance_date`) and the date filters in
/// PowerSync sync rules.
String dateKey(DateTime dt) {
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '${dt.year}-$m-$d';
}

/// `HH:MM` (24-hour) from the local-time components of [dt].
///
/// Use for compact time chips on schedule blocks, pickup windows,
/// and observation timestamps. Locale-aware time formatting goes
/// through `DateFormat.jm()`.
String timeOfDay(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// `dateKey` of "now" — sugar for the common case.
String todayKey() => dateKey(DateTime.now());
