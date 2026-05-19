/// Short, human-readable "time since" string for a past [DateTime].
///
/// Returns `''` for `null` (callers can blindly drop this in a `Text`
/// widget without nullish-check noise). Calibration:
///
///   < 1 min        → "just now"
///   < 60 min       → "5 min ago"
///   < 24 hours     → "3 h ago"
///   1 day          → "yesterday"
///   < 7 days       → "4 days ago"
///   < 52 weeks     → "6 wk ago"
///   ≥ 52 weeks     → "2 y ago"
///
/// One canonical implementation — replaces the three earlier copies in
/// sync_status_indicator / captures / insights. If a feature needs a
/// different cut (e.g. a sync widget that wants seconds for "just
/// now"), pass `precision: TimePrecision.seconds`.
String relativeTimeAgo(DateTime? when, {TimePrecision? precision}) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.isNegative) return 'just now';
  if (precision == TimePrecision.seconds && diff.inMinutes < 1) {
    return '${diff.inSeconds}s ago';
  }
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  if (diff.inDays < 365) return '${(diff.inDays / 7).floor()} wk ago';
  return '${(diff.inDays / 365).floor()} y ago';
}

/// Optional refinement for [relativeTimeAgo]. Defaults to minute
/// granularity; sync widgets that want fresh-looking timestamps pass
/// [seconds] so "12s ago" shows instead of "just now" within the
/// first minute.
enum TimePrecision {
  minutes,
  seconds,
}
