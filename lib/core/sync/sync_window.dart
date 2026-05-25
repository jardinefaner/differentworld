import 'package:differentworld/shared/format/date_keys.dart';

/// Time-window helpers for the parameterized PowerSync streams.
///
/// PowerSync's sync-rule SQL subset doesn't support `now()` / `date()`
/// / `INTERVAL` — the supported pattern is a client-supplied parameter
/// (`request.parameters.<name>`) passed via `db.syncStream(...).subscribe(
/// parameters: {...})`. This module owns the math for "what cutoff
/// should we ship to the server right now."
///
/// Why client-side: PowerSync's auto-subscribe streams can't pass
/// parameters. The recent / time-sensitive tables (entries,
/// attendance_records, vehicle_logs) are pulled out into a separate
/// `by_space_recent` stream with `auto_subscribe: false`; the app
/// subscribes manually at connect time with the cutoff filled in.
///
/// Day-rollover: the window has to slide. We compute the cutoff
/// fresh on every `subscribe()`, then schedule a re-subscribe at the
/// next local midnight so a long-running session doesn't end up
/// reading rows older than the intended window after midnight ticks.
///
/// Status (May 2026): the client-side plumbing is built (see
/// `powerSyncLifecycleProvider`); the matching `by_space_recent`
/// sync-rules stream isn't deployed yet — see
/// `docs/SCALE_PUNCH_LIST.md`. Until the dashboard YAML is flipped,
/// the subscribe call is a no-op against a non-existent stream and
/// PowerSync logs a warning. That's expected; nothing else breaks.
class SyncWindow {
  const SyncWindow._();

  /// Default lookback for the recent-entries stream. Tunable per
  /// program later (heavier observers may want longer history at
  /// hand); 90 days is a comfortable "current term" snapshot.
  static const Duration defaultLookback = Duration(days: 90);

  /// The cutoff timestamp to pass as the `cutoff_at` sync parameter.
  /// ISO-8601 UTC string — PowerSync's SQL evaluation expects the
  /// server's `timestamptz` columns to compare against this.
  static String cutoffIsoNow({Duration lookback = defaultLookback}) {
    final cutoff = DateTime.now().toUtc().subtract(lookback);
    return cutoff.toIso8601String();
  }

  /// Date-only form of the cutoff for tables that store dates as
  /// `YYYY-MM-DD` strings (attendance_records.date). Local time —
  /// "what was the date 90 days before today, in the user's tz."
  static String cutoffDateNow({Duration lookback = defaultLookback}) =>
      dateKey(DateTime.now().subtract(lookback));

  /// Duration from now until the next local midnight. Use this to
  /// schedule a re-subscribe so the window slides at day rollover.
  static Duration timeUntilNextLocalMidnight() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }
}
