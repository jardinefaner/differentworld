import 'package:differentworld/features/rooms/room_load.dart';
import 'package:differentworld/features/rooms/room_load_providers.dart';
import 'package:differentworld/shared/widgets/accent_edge_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How full this room is, on the room itself (docs/ROOMS.md).
///
/// Reads in half a second, because that is all the attention available when
/// a parent is standing in front of you asking whether you have a space:
/// the headline is the count, the line under it is what it means, and a
/// breach turns the whole thing the error colour rather than adding a badge
/// you have to notice.
///
/// Renders nothing when the room has no numbers on file — an unchecked room
/// gets a quiet prompt in Edit, not a permanent scold here.
class RoomLoadBar extends ConsumerWidget {
  const RoomLoadBar({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final load = ref.watch(roomLoadProvider(groupId));
    if (load.unchecked) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final bad = load.breached;
    final colour = bad ? theme.colorScheme.error : theme.colorScheme.primary;

    return AccentEdgeRow(
      margin: const EdgeInsets.only(bottom: 12),
      accent: colour,
      title: _headline(load),
      subtitle: _detail(load),
      subtitleColor: colour,
    );
  }

  String _headline(RoomLoad l) {
    final children = l.childrenPresent == 1
        ? '1 child here'
        : '${l.childrenPresent} children here';
    final staff = l.staffAssigned == 1
        ? '1 adult assigned'
        : '${l.staffAssigned} adults assigned';
    return '$children · $staff';
  }

  String _detail(RoomLoad l) {
    // Most-serious first: being over the licensed number is the one that
    // ends an inspection, and hearing about spare places at that moment
    // would be absurd.
    if (l.overCapacity) {
      final over = l.childrenPresent - l.licensedCapacity!;
      return 'Over the licensed limit of ${l.licensedCapacity} by $over.';
    }
    if (l.understaffed) {
      final short = l.staffShort!;
      return 'Ratio needs ${l.staffRequired} adults at '
          '1:${l.ratioChildrenPerAdult} — $short more.';
    }
    final spare = l.roomFor;
    if (spare == null) return 'Within the room’s limits.';
    if (spare == 0) return 'Full — no space for another child right now.';
    return 'Room for $spare more.';
  }
}
