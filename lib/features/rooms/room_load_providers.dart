import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/attendance/present_today.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/rooms/room_load.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Staff assigned to a room. Assignment, not presence — the app has no
/// clock-in, and [RoomLoad] is explicit about the difference.
// ignore: specify_nonobvious_property_types
final staffOnGroupProvider = StreamProvider.autoDispose
    .family<List<GroupMember>, String>((ref, groupId) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.groupMembersDao.watchForGroup(groupId);
    });

/// How full a room is right now, against its own numbers.
///
/// Children counted are those actually HERE — attendance decides, falling
/// back to the roster before anyone has been marked. A ratio computed from
/// the roster on a day when half the room is absent would raise alarms
/// nobody needs.
// ignore: specify_nonobvious_property_types
final roomLoadProvider = Provider.autoDispose.family<RoomLoad, String>((
  ref,
  groupId,
) {
  final present = ref.watch(presentSubjectsProvider(groupId)).length;

  final staff = ref.watch(staffOnGroupProvider(groupId)).value ?? const [];
  final group = (ref.watch(groupsProvider).value ?? const <Group>[])
      .where((g) => g.id == groupId)
      .firstOrNull;
  final caps = group?.caps ?? Capabilities(const {});

  return RoomLoad(
    childrenPresent: present,
    staffAssigned: staff.length,
    licensedCapacity: caps.getInt(GroupCaps.licensedCapacity),
    ratioChildrenPerAdult: caps.getInt(GroupCaps.ratioChildrenPerAdult),
  );
});

/// Every room currently breaching capacity or ratio — what the day-one
/// briefing and the director's overview both need in one read.
final Provider<List<(Group, RoomLoad)>> breachedRoomsProvider =
    Provider.autoDispose<List<(Group, RoomLoad)>>((ref) {
      final groups = ref.watch(groupsProvider).value ?? const <Group>[];
      return [
        for (final g in groups)
          if (ref.watch(roomLoadProvider(g.id)).breached)
            (g, ref.watch(roomLoadProvider(g.id))),
      ];
    });
