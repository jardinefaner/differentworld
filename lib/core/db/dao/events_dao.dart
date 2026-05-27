import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';

part 'events_dao.g.dart';

/// Wave 158: one-off events overlaying the regular schedule.
///
/// `groupIds` is stored as a JSON-encoded list of strings on the
/// row (PowerSync surfaces jsonb as text). Empty list = applies to
/// every cohort in the space. The renderer parses this on read; we
/// don't bother with a typed companion since the array is short.
@DriftAccessor(tables: [Events])
class EventsDao extends DatabaseAccessor<AppDatabase>
    with _$EventsDaoMixin {
  EventsDao(super.attachedDatabase);

  /// Stream every event for a single date in the space.
  Stream<List<Event>> watchForDate({
    required String spaceId,
    required String date,
  }) {
    return (select(events)
          ..where((e) => e.spaceId.equals(spaceId) & e.date.equals(date))
          ..orderBy([(e) => OrderingTerm(expression: e.startAt)]))
        .watch();
  }

  /// Stream all events between two ISO dates inclusive — drives the
  /// upcoming-events teaser on Today and the family lens calendar.
  Stream<List<Event>> watchInRange({
    required String spaceId,
    required String fromIsoDate,
    required String toIsoDate,
  }) {
    return (select(events)
          ..where((e) =>
              e.spaceId.equals(spaceId) &
              e.date.isBiggerOrEqualValue(fromIsoDate) &
              e.date.isSmallerOrEqualValue(toIsoDate))
          ..orderBy([(e) => OrderingTerm(expression: e.date)]))
        .watch();
  }

  Future<String> create({
    required String id,
    required String spaceId,
    required String date,
    required String title,
    required String mode,
    required String groupIdsJson,
    String? startAt,
    String? endAt,
    String? description,
    String? color,
    String? locationId,
    String? createdBy,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await into(events).insert(
      EventsCompanion.insert(
        id: id,
        spaceId: spaceId,
        date: date,
        title: title,
        mode: mode,
        groupIds: groupIdsJson,
        startAt: Value(startAt),
        endAt: Value(endAt),
        description: Value(description),
        color: Value(color),
        locationId: Value(locationId),
        createdBy: Value(createdBy),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> delete_(String id) async {
    await (delete(events)..where((e) => e.id.equals(id))).go();
  }
}
