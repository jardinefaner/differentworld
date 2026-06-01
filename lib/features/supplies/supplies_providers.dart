import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The program's supplies catalog (docs/SUPPLIES.md). Watched live so the
/// list — and (slice 2) the activity supply picker — see edits in real
/// time. Local-first: the stream is Drift; PowerSync syncs in the
/// background.
final suppliesProvider = StreamProvider<List<Supply>>((ref) {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final db = ref.watch(appDatabaseProvider).value;
  if (spaceId == null || db == null) {
    return Stream<List<Supply>>.value(const []);
  }
  return db.suppliesDao.watchInSpace(spaceId);
});

class SupplyActions {
  SupplyActions(this._ref);
  final Ref _ref;

  Future<String> create({
    required String name,
    String? category,
    double? quantity,
    String? unit,
    String? location,
    double? lowStockThreshold,
    String? notes,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'add a supply');
    final db = await _ref.read(appDatabaseProvider.future);
    return db.suppliesDao.create(
      spaceId: spaceId,
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      location: location,
      lowStockThreshold: lowStockThreshold,
      notes: notes,
    );
  }

  Future<void> update_({
    required String id,
    String? name,
    String? category,
    double? quantity,
    String? unit,
    String? location,
    double? lowStockThreshold,
    String? notes,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.suppliesDao.update_(
      id: id,
      name: name,
      category: category,
      quantity: quantity,
      unit: unit,
      location: location,
      lowStockThreshold: lowStockThreshold,
      notes: notes,
    );
  }

  Future<void> delete_(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.suppliesDao.delete_(id);
  }
}

final supplyActionsProvider = Provider<SupplyActions>(SupplyActions.new);
