import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locations registered in the current space — pool, art barn,
/// archery range, etc. Watched live so the activity edit screen and
/// schedule block sheet see additions in real time.
final locationsProvider = StreamProvider<List<Location>>((ref) {
  final viewer = ref.watch(viewerProvider);
  final spaceId = viewer.spaceId;
  final db = ref.watch(appDatabaseProvider).value;
  if (spaceId == null || db == null) {
    return Stream<List<Location>>.value(const []);
  }
  return db.locationsDao.watchInSpace(spaceId);
});

class LocationActions {
  LocationActions(this._ref);
  final Ref _ref;

  Future<String> create({
    required String name,
    String? notes,
    int? capacity,
    bool isOutdoor = false,
  }) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'create a location');
    final db = await _ref.read(appDatabaseProvider.future);
    return db.locationsDao.create(
      spaceId: spaceId,
      name: name,
      notes: notes,
      capacity: capacity,
      isOutdoor: isOutdoor,
    );
  }

  Future<void> update_({
    required String id,
    String? name,
    String? notes,
    int? capacity,
    bool? isOutdoor,
  }) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.locationsDao.update_(
      id: id,
      name: name,
      notes: notes,
      capacity: capacity,
      isOutdoor: isOutdoor,
    );
  }

  Future<void> delete_(String id) async {
    final db = await _ref.read(appDatabaseProvider.future);
    await db.locationsDao.delete_(id);
  }
}

final locationActionsProvider =
    Provider<LocationActions>(LocationActions.new);
