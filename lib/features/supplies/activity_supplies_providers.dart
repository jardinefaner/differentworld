import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A pick on an activity's pack list: which supply, and how many.
typedef SupplyPick = ({String supplyId, double? quantity});

/// The supply links for one activity (docs/SUPPLIES.md pack lists). Live, so
/// the editor seeds from it and the activity's "you'll need…" reflects edits.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final activitySupplyLinksProvider = StreamProvider.autoDispose
    .family<List<ActivitySupply>, String>((
      ref,
      activityId,
    ) async* {
      final db = ref.watch(appDatabaseProvider).value;
      // Do NOT yield an empty sentinel before the DB is ready: the editor's
      // seed-once guard (_picksSeeded) would latch onto [] and silently drop
      // the real links when they arrive — and a save would then wipe the
      // pack list. Stay in loading; this provider re-runs when
      // appDatabaseProvider resolves. A genuinely link-less activity still
      // gets a real [] from the Drift query below (correct seed).
      if (db == null) return;
      yield* db.activitySuppliesDao.watchForActivity(activityId);
    });

class ActivitySuppliesActions {
  ActivitySuppliesActions(this._ref);
  final Ref _ref;

  /// Replace the whole set of supply links for [activityId].
  Future<void> setForActivity(
    String activityId,
    List<SupplyPick> picks,
  ) async {
    final viewer = _ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'set activity supplies');
    final db = await _ref.read(appDatabaseProvider.future);
    await db.activitySuppliesDao.replaceForActivity(
      activityId: activityId,
      spaceId: spaceId,
      picks: picks,
    );
  }
}

final activitySuppliesActionsProvider = Provider<ActivitySuppliesActions>(
  ActivitySuppliesActions.new,
);
