import 'package:differentworld/core/db/app_database.dart';
import 'package:flutter/material.dart';

/// The cohort selector row — one `ChoiceChip` per group, shown only when
/// there's more than one to choose from. Shared by the screens that pin a
/// header + cohort picker above a per-group body (recap composer, routines).
class GroupChipRow extends StatelessWidget {
  const GroupChipRow({
    required this.groups,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<Group> groups;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (groups.length < 2) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        children: [
          for (final g in groups)
            ChoiceChip(
              label: Text(g.name),
              selected: g.id == selectedId,
              onSelected: (_) => onSelected(g.id),
            ),
        ],
      ),
    );
  }
}
