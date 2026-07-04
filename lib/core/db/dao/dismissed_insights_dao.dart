import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'dismissed_insights_dao.g.dart';

/// Per-member snooze rows for the derived insights surface.
///
/// Insights are computed on-device from existing data (no insights
/// table); these rows record that *this member* has muted *this
/// insight_id* until `dismissedUntil`. When that passes (or is null
/// = "until I undismiss it manually"), the row reappears.
@DriftAccessor(tables: [DismissedInsights])
class DismissedInsightsDao extends DatabaseAccessor<AppDatabase>
    with _$DismissedInsightsDaoMixin {
  DismissedInsightsDao(super.attachedDatabase);

  Stream<List<DismissedInsight>> watchForMember(String memberId) {
    return (select(
      dismissedInsights,
    )..where((d) => d.memberId.equals(memberId))).watch();
  }

  Future<DismissedInsight?> findFor({
    required String memberId,
    required String insightId,
  }) {
    return (select(dismissedInsights)..where(
          (d) => d.memberId.equals(memberId) & d.insightId.equals(insightId),
        ))
        .getSingleOrNull();
  }

  /// Upsert by (member_id, insight_id). Re-dismissing replaces the
  /// row with a new `dismissed_until`.
  Future<void> upsert({
    required String id,
    required String spaceId,
    required String memberId,
    required String insightId,
    required DateTime? dismissedUntil,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = await findFor(
      memberId: memberId,
      insightId: insightId,
    );
    final untilIso = dismissedUntil?.toUtc().toIso8601String();
    if (existing == null) {
      await into(dismissedInsights).insert(
        DismissedInsightsCompanion.insert(
          id: id,
          spaceId: spaceId,
          memberId: memberId,
          insightId: insightId,
          dismissedUntil: Value(untilIso),
          createdAt: now,
        ),
      );
      return;
    }
    await (update(
      dismissedInsights,
    )..where((d) => d.id.equals(existing.id))).write(
      DismissedInsightsCompanion(
        dismissedUntil: Value(untilIso),
      ),
    );
  }

  Future<void> deleteFor({
    required String memberId,
    required String insightId,
  }) async {
    await (delete(dismissedInsights)..where(
          (d) => d.memberId.equals(memberId) & d.insightId.equals(insightId),
        ))
        .go();
  }
}
