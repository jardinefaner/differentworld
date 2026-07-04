import 'package:differentworld/core/db/app_database.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

part 'supplies_dao.g.dart';

/// The program's real-world inventory (docs/SUPPLIES.md). A catalog the
/// program maintains once; other features reference rows by id. Mutations
/// write through Drift; PowerSync syncs space-scoped.
@DriftAccessor(tables: [Supplies])
class SuppliesDao extends DatabaseAccessor<AppDatabase>
    with _$SuppliesDaoMixin {
  SuppliesDao(super.attachedDatabase);

  static const _uuid = Uuid();

  /// All supplies in [spaceId], ordered by category then name so the list
  /// groups cleanly.
  Stream<List<Supply>> watchInSpace(String spaceId) {
    return (select(supplies)
          ..where((s) => s.spaceId.equals(spaceId))
          ..orderBy([
            (s) => OrderingTerm(expression: s.category),
            (s) => OrderingTerm(expression: s.name),
          ]))
        .watch();
  }

  Stream<Supply?> watchById(String id) {
    return (select(
      supplies,
    )..where((s) => s.id.equals(id))).watchSingleOrNull();
  }

  Future<String> create({
    required String spaceId,
    required String name,
    String? category,
    double? quantity,
    String? unit,
    String? location,
    String? locationId,
    double? lowStockThreshold,
    String? photoUrl,
    String? notes,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await into(supplies).insert(
      SuppliesCompanion.insert(
        id: id,
        spaceId: spaceId,
        name: name,
        category: Value(category),
        quantity: Value(quantity),
        unit: Value(unit),
        location: Value(location),
        locationId: Value(locationId),
        lowStockThreshold: Value(lowStockThreshold),
        photoUrl: Value(photoUrl),
        notes: Value(notes),
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  /// `clearLocationId: true` explicitly unsets the location link (the
  /// nullable-update escape hatch the trailing-null convention can't
  /// express — used when the picker is set back to "None").
  Future<void> update_({
    required String id,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    String? location,
    String? locationId,
    bool clearLocationId = false,
    double? lowStockThreshold,
    String? photoUrl,
    String? notes,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (update(supplies)..where((s) => s.id.equals(id))).write(
      SuppliesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        category: category == null ? const Value.absent() : Value(category),
        quantity: quantity == null ? const Value.absent() : Value(quantity),
        unit: unit == null ? const Value.absent() : Value(unit),
        location: location == null ? const Value.absent() : Value(location),
        locationId: clearLocationId
            ? const Value(null)
            : (locationId == null ? const Value.absent() : Value(locationId)),
        lowStockThreshold: lowStockThreshold == null
            ? const Value.absent()
            : Value(lowStockThreshold),
        photoUrl: photoUrl == null ? const Value.absent() : Value(photoUrl),
        notes: notes == null ? const Value.absent() : Value(notes),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> delete_(String id) async {
    await (delete(supplies)..where((s) => s.id.equals(id))).go();
  }
}
