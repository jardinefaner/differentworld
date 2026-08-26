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
  // `.toLocal()` is load-bearing, not defensive noise. Every timestamp in
  // this app is stored as a UTC ISO string, so `DateTime.tryParse` of a
  // stored value hands back a UTC DateTime whose `.year/.month/.day` are UTC
  // components — and this doc comment has always PROMISED local ones. A
  // block at 16:30 local rendered as the previous day's date whenever the
  // offset crossed midnight. No-op for a DateTime that is already local.
  final local = dt.toLocal();
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

/// `HH:MM` (24-hour) from the local-time components of [dt].
///
/// Use for compact time chips on schedule blocks, pickup windows,
/// and observation timestamps. Locale-aware time formatting goes
/// through `DateFormat.jm()`.
String timeOfDay(DateTime dt) {
  // Same reason as [dateKey], and this is the one people SEE: a parsed
  // stored timestamp is UTC, so reading `.hour` off it showed the room a
  // time shifted by the whole UTC offset. Fixing it here rather than at
  // each call site is deliberate — the correct-but-forgettable
  // `DateTime.tryParse(x)?.toLocal()` dance was already missing from
  // several surfaces, and a formatter that is only right when every caller
  // remembers something is a formatter that will be wrong again.
  final local = dt.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// `dateKey` of "now" — sugar for the common case.
String todayKey() => dateKey(DateTime.now());
