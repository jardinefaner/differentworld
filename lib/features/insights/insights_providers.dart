import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/certifications/certifications_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Insights are the visible part of the upward loop — the system
/// watches what Surface produces, finds patterns, and surfaces them
/// as *questions with concrete next moves*, never as a dashboard.
///
/// Every insight kind here derives from data already in PowerSync —
/// no new schema. Each kind has a deterministic `id` so renders
/// across rebuilds stay stable (and so dismissal/snooze can land on
/// the same row later when we add it).
enum InsightSeverity {
  /// Time-sensitive — likely worth doing today.
  urgent,

  /// Worth attention, not blocking — review next time you're there.
  suggestion,

  /// Just-FYI; the user can skim or ignore.
  info,
}

enum InsightKind {
  attendanceLateStreak,
  certExpiringSoon,
  certAlreadyExpired,
  vehicleNeedsRepair,
  vehicleUnsafe,
  quietKid,
  surveyOpen,
}

/// One actionable insight. Routing is data — the UI renders the
/// prompt + actions verbatim.
@immutable
class Insight {
  const Insight({
    required this.id,
    required this.kind,
    required this.severity,
    required this.prompt,
    required this.actions,
    this.subjectName,
    this.memberName,
    this.vehicleName,
  });

  final String id;
  final InsightKind kind;
  final InsightSeverity severity;

  /// The question shown to the user, plain English.
  final String prompt;

  /// One to three concrete next moves. First is the default
  /// (rendered as the prominent button); the rest are secondary.
  final List<InsightAction> actions;

  final String? subjectName;
  final String? memberName;
  final String? vehicleName;

  IconData get icon => switch (kind) {
        InsightKind.attendanceLateStreak => Icons.schedule_outlined,
        InsightKind.certExpiringSoon => Icons.workspace_premium_outlined,
        InsightKind.certAlreadyExpired => Icons.warning_amber_outlined,
        InsightKind.vehicleNeedsRepair => Icons.handyman_outlined,
        InsightKind.vehicleUnsafe => Icons.dangerous_outlined,
        InsightKind.quietKid => Icons.menu_book_outlined,
        InsightKind.surveyOpen => Icons.poll_outlined,
      };
}

@immutable
class InsightAction {
  const InsightAction({required this.label, required this.route});

  final String label;

  /// Canonical destination. Tapping the action navigates here via
  /// `context.push(route)`. Per UX_DECISIONS §9 — actions route to
  /// existing screens, never reimplement the flow inline.
  final String route;
}

/// Per-member set of insight_ids that are currently snoozed. An entry
/// with `dismissed_until` null is muted indefinitely (until the user
/// explicitly un-snoozes). An entry with a timestamp re-surfaces
/// automatically when the timestamp passes.
final _dismissedInsightIdsProvider =
    StreamProvider<Set<String>>((ref) async* {
  final viewer = ref.watch(viewerProvider);
  final memberId = viewer.memberId;
  if (memberId == null) {
    yield <String>{};
    return;
  }
  final db = await ref.watch(appDatabaseProvider.future);
  yield* db.dismissedInsightsDao.watchForMember(memberId).map((rows) {
    final now = DateTime.now();
    final active = <String>{};
    for (final r in rows) {
      final iso = r.dismissedUntil;
      if (iso == null || iso.isEmpty) {
        active.add(r.insightId);
        continue;
      }
      final until = DateTime.tryParse(iso);
      if (until == null || until.isAfter(now)) {
        active.add(r.insightId);
      }
      // else: expired snooze — drop from the active set so the
      // insight re-surfaces. The row stays in the DB so we can show
      // "re-snoozed N times" if we ever want that metric.
    }
    return active;
  });
});

/// The full sorted list of insights for the current viewer, with
/// snoozed ones filtered out. Severity first (urgent → suggestion →
/// info), then by kind for stable order across rebuilds.
final insightsProvider = Provider<AsyncValue<List<Insight>>>((ref) {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  if (spaceId == null) return const AsyncValue.data([]);

  final subjectsAsync = ref.watch(subjectsInSpaceProvider);
  final certsAsync = ref.watch(certsInSpaceProvider);
  final vehiclesAsync = ref.watch(vehiclesProvider);
  final observationsAsync = ref.watch(observationsInSpaceProvider);
  final dismissedAsync = ref.watch(_dismissedInsightIdsProvider);

  if (subjectsAsync.isLoading ||
      certsAsync.isLoading ||
      vehiclesAsync.isLoading ||
      observationsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final subjects = subjectsAsync.value ?? const <Subject>[];
  final certs = certsAsync.value ?? const <MemberCertification>[];
  final vehicles = vehiclesAsync.value ?? const <Vehicle>[];
  final observations = observationsAsync.value ?? const <Entry>[];
  final dismissed = dismissedAsync.value ?? const <String>{};

  final insights = <Insight>[
    ..._certInsights(certs),
    ..._vehicleInsights(ref, vehicles),
    ..._quietKidInsights(subjects, observations),
    ..._attendanceInsights(ref, subjects),
    ..._surveyInsights(ref, spaceId, subjects),
  ].where((i) => !dismissed.contains(i.id)).toList()
    ..sort((a, b) {
      final s = a.severity.index.compareTo(b.severity.index);
      if (s != 0) return s;
      return a.kind.index.compareTo(b.kind.index);
    });
  return AsyncValue.data(List<Insight>.unmodifiable(insights));
});

/// Snooze options offered on each insight card. Concrete choices so
/// the user doesn't have to think — "until tomorrow" is the
/// most-used by design.
enum InsightSnoozeOption {
  untilTomorrow,
  untilNextWeek,
  untilFurtherNotice,
}

extension InsightSnoozeOptionX on InsightSnoozeOption {
  String get label => switch (this) {
        InsightSnoozeOption.untilTomorrow => 'Snooze until tomorrow',
        InsightSnoozeOption.untilNextWeek => 'Snooze for a week',
        InsightSnoozeOption.untilFurtherNotice =>
          'Hide until I unhide it',
      };

  /// Returns the resolved `dismissed_until` timestamp, or null for
  /// "indefinitely."
  DateTime? resolveUntil() {
    final now = DateTime.now();
    return switch (this) {
      InsightSnoozeOption.untilTomorrow =>
        DateTime(now.year, now.month, now.day + 1, 6),
      InsightSnoozeOption.untilNextWeek =>
        DateTime(now.year, now.month, now.day + 7, 6),
      InsightSnoozeOption.untilFurtherNotice => null,
    };
  }
}

class InsightActions {
  InsightActions(this._ref);

  final Ref _ref;
  final Uuid _uuid = const Uuid();

  Future<void> snooze({
    required String insightId,
    required InsightSnoozeOption option,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final (:spaceId, :memberId) =
        viewer.requireSpaceAndMember(action: 'snooze an insight');
    final db = await _ref.read(appDatabaseProvider.future);
    await db.dismissedInsightsDao.upsert(
      id: _uuid.v4(),
      spaceId: spaceId,
      memberId: memberId,
      insightId: insightId,
      dismissedUntil: option.resolveUntil(),
    );
  }

  Future<void> unsnooze(String insightId) async {
    final viewer = _ref.read(viewerProvider);
    final memberId = viewer.memberId;
    if (memberId == null) return;
    final db = await _ref.read(appDatabaseProvider.future);
    await db.dismissedInsightsDao.deleteFor(
      memberId: memberId,
      insightId: insightId,
    );
  }
}

final insightActionsProvider =
    Provider<InsightActions>(InsightActions.new);

// ---------------------------------------------------------------------------
// Derivations — pure-ish functions over the streams handed in. Each
// kind is auditable in isolation; adding a new insight kind = add a
// helper here + add to the assembly above.
// ---------------------------------------------------------------------------

List<Insight> _certInsights(List<MemberCertification> certs) {
  final out = <Insight>[];
  final today = _today();
  for (final c in certs) {
    final iso = c.expiresAt;
    if (iso == null || iso.isEmpty) continue;
    final dt = DateTime.tryParse(iso);
    if (dt == null) continue;
    final days = dt.difference(today).inDays;
    if (days < 0) {
      out.add(Insight(
        id: 'cert_expired_${c.memberId}_${c.certKey}',
        kind: InsightKind.certAlreadyExpired,
        severity: InsightSeverity.urgent,
        prompt: '${_certLabel(c.certKey)} is expired '
            '(${days.abs()} ${days == -1 ? 'day' : 'days'} ago). '
            'Renew now?',
        actions: [
          InsightAction(
            label: 'Open team member',
            route: '/settings/team/${c.memberId}',
          ),
        ],
      ));
    } else if (days <= 30) {
      out.add(Insight(
        id: 'cert_soon_${c.memberId}_${c.certKey}',
        kind: InsightKind.certExpiringSoon,
        severity:
            days <= 7 ? InsightSeverity.urgent : InsightSeverity.suggestion,
        prompt: '${_certLabel(c.certKey)} expires in $days '
            '${days == 1 ? 'day' : 'days'}. '
            'Start the renewal?',
        actions: [
          InsightAction(
            label: 'Open team member',
            route: '/settings/team/${c.memberId}',
          ),
        ],
      ));
    }
  }
  return out;
}

/// Surface a vehicle insight when the latest inspection flagged any
/// item as `needs_repair` or `unsafe`. A later check-in clearing the
/// issue replaces the latest log in the stream, so the insight
/// drops off automatically — no manual dismissal needed.
List<Insight> _vehicleInsights(Ref ref, List<Vehicle> vehicles) {
  final out = <Insight>[];
  for (final v in vehicles) {
    final logsAsync = ref.watch(vehicleLogsProvider(v.id));
    final logs = logsAsync.value ?? const <VehicleLog>[];
    if (logs.isEmpty) continue;
    final latest = logs.first;
    final items = _parseInspectionItems(latest.items);
    var anyUnsafe = false;
    var anyNeedsRepair = false;
    for (final section in items.values) {
      for (final status in section.values) {
        if (status == 'unsafe') anyUnsafe = true;
        if (status == 'needs_repair') anyNeedsRepair = true;
      }
    }
    if (anyUnsafe) {
      out.add(Insight(
        id: 'vehicle_unsafe_${v.id}',
        kind: InsightKind.vehicleUnsafe,
        severity: InsightSeverity.urgent,
        vehicleName: v.name,
        prompt: '${v.name} was flagged unsafe on the last inspection. '
            "Don't drive — schedule a mechanic.",
        actions: [
          InsightAction(
            label: 'Open vehicle',
            route: '/vehicles/${v.id}',
          ),
        ],
      ));
    } else if (anyNeedsRepair) {
      out.add(Insight(
        id: 'vehicle_repair_${v.id}',
        kind: InsightKind.vehicleNeedsRepair,
        severity: InsightSeverity.suggestion,
        vehicleName: v.name,
        prompt: '${v.name} has items flagged "needs repair" on the '
            'last inspection. Worth a mechanic visit soon.',
        actions: [
          InsightAction(
            label: 'Open vehicle',
            route: '/vehicles/${v.id}',
          ),
        ],
      ));
    }
  }
  return out;
}

/// A kid with no observations for ≥ 21 days is a quiet-kid signal —
/// either the teacher's behind on logging, or that child is sliding
/// under the radar. Either way, worth surfacing.
List<Insight> _quietKidInsights(
  List<Subject> subjects,
  List<Entry> observations,
) {
  final out = <Insight>[];
  final cutoff = _today().subtract(const Duration(days: 21));
  final mostRecentBySubject = <String, DateTime>{};
  for (final e in observations) {
    final id = e.subjectId;
    if (id == null) continue;
    final dt = DateTime.tryParse(e.recordedAt);
    if (dt == null) continue;
    final prior = mostRecentBySubject[id];
    if (prior == null || dt.isAfter(prior)) {
      mostRecentBySubject[id] = dt;
    }
  }
  for (final s in subjects) {
    if (s.groupId == null) continue;
    final last = mostRecentBySubject[s.id];
    if (last != null && last.isAfter(cutoff)) continue;
    final daysSince = last == null
        ? 'No observations yet this year'
        : '${_today().difference(last).inDays} days since the last observation';
    out.add(Insight(
      id: 'quiet_kid_${s.id}',
      kind: InsightKind.quietKid,
      severity: InsightSeverity.info,
      subjectName: '${s.firstName} ${s.lastName}',
      prompt: "${s.firstName} ${s.lastName} hasn't had an observation "
          'in a while — $daysSince. Worth a check-in this week.',
      actions: [
        InsightAction(
          label: 'Open child',
          route: '/groups/${s.groupId}/students/${s.id}',
        ),
      ],
    ));
  }
  return out;
}

/// Surface when a kid has been late ≥ 2 days in the last 7 calendar
/// days. Reads each subject's attendance history stream — fan-out
/// looks heavy but every row is already on device.
List<Insight> _attendanceInsights(Ref ref, List<Subject> subjects) {
  final out = <Insight>[];
  final cutoff = _today().subtract(const Duration(days: 7));
  for (final s in subjects) {
    final historyAsync = ref.watch(attendanceHistoryForSubjectProvider(s.id));
    final history = historyAsync.value ?? const <AttendanceRecord>[];
    var lateCount = 0;
    for (final r in history) {
      final date = DateTime.tryParse(r.date);
      if (date == null || date.isBefore(cutoff)) continue;
      if (AttendanceStatus.fromDb(r.status) == AttendanceStatus.late) {
        lateCount++;
      }
    }
    if (lateCount < 2 || s.groupId == null) continue;
    out.add(Insight(
      id: 'late_streak_${s.id}',
      kind: InsightKind.attendanceLateStreak,
      severity: InsightSeverity.suggestion,
      subjectName: '${s.firstName} ${s.lastName}',
      prompt:
          '${s.firstName} ${s.lastName} has been late $lateCount times this '
          'week. Want to reach out to family?',
      actions: [
        InsightAction(
          label: 'Open child',
          route: '/groups/${s.groupId}/students/${s.id}',
        ),
      ],
    ));
  }
  return out;
}

List<Insight> _surveyInsights(
  Ref ref,
  String spaceId,
  List<Subject> subjects,
) {
  // Wave 138/140: surveys are anonymous now — responses don't link to
  // a specific kid, so "X students left to complete" stopped being a
  // computable signal. The whole insight is dropped until we design
  // a new aggregate signal (e.g. "N responses recorded this week" or
  // "low signal: only 2 responses to BASECamp 25-26 in 30 days").
  return const <Insight>[];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String _certLabel(String key) => switch (key) {
      'mat' => 'MAT certification',
      'cpr' => 'CPR certification',
      'first_aid' => 'First-aid certification',
      'background' => 'Background check',
      'driver' => 'Driver certification',
      _ => key,
    };

/// `vehicle_logs.items` JSONB shape: `{section: {item_key: status}}`.
/// Tolerates malformed strings — returns empty rather than throwing.
Map<String, Map<String, String>> _parseInspectionItems(String json) {
  if (json.isEmpty) return const {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return const {};
    final out = <String, Map<String, String>>{};
    for (final entry in decoded.entries) {
      final inner = entry.value;
      if (inner is! Map) continue;
      out[entry.key.toString()] = {
        for (final ie in inner.entries) ie.key.toString(): ie.value.toString(),
      };
    }
    return out;
  } on FormatException {
    return const {};
  }
}
