import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';

/// Resolve a sticky cohort pick against the live list: the picked id if
/// it's still present, otherwise the first group (null when there are
/// none). Shared by the run-day / propose-day cohort switchers.
Group? resolveGroup(List<Group> groups, String? groupId) {
  for (final g in groups) {
    if (g.id == groupId) return g;
  }
  return groups.isEmpty ? null : groups.first;
}

/// Glass-sheet cohort picker — one row per group, a check on the current
/// pick. Resolves to the tapped group's id, or null when dismissed.
Future<String?> showGroupPickerSheet(
  BuildContext context, {
  required List<Group> groups,
  required String? currentId,
}) {
  return showGlassSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final g in groups)
            ListTile(
              title: Text(g.name),
              trailing: g.id == currentId ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(ctx).pop(g.id),
            ),
        ],
      ),
    ),
  );
}
