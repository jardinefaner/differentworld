import 'dart:async';

import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pat persona — a director's one-tap "X is out today, Y is
/// covering" surface, scoped to one cohort × one date.
///
/// The sheet enumerates the distinct planned leads in this group's
/// blocks for the date, with a count next to each. For each:
///
/// * If no substitute is set yet, a "Cover" button opens a picker
///   that lists every other member in the space; choosing one bulk-
///   writes `lead_substitute_member_id` across all matching blocks.
/// * If a substitute is already set, the row shows "Covered by …"
///   and a "Restore" button that clears it.
///
/// The sheet only touches `lead_substitute_member_id` — the original
/// `lead_member_id` is preserved so the planned roster survives for
/// audit / "who was supposed to lead?" questions.
class SubstituteLeadSheet extends ConsumerWidget {
  const SubstituteLeadSheet({
    required this.groupId,
    required this.groupName,
    required this.date,
    super.key,
  });

  final String groupId;
  final String groupName;

  /// ISO `YYYY-MM-DD` — the date this sheet acts on. We display
  /// "Today" / "Tomorrow" copy at the call site; here we just store
  /// the exact string we pass to the DAO.
  final String date;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String groupName,
    required String date,
  }) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SubstituteLeadSheet(
        groupId: groupId,
        groupName: groupName,
        date: date,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final blocksAsync = ref.watch(
      scheduleDayForGroupProvider((groupId: groupId, date: date)),
    );
    final members =
        ref.watch(membersInSpaceProvider).value ?? const <Member>[];
    final memberById = <String, Member>{
      for (final m in members) m.id: m,
    };

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          top: 4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Cover today's lead",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              "$groupName · pick the absent counselor and who's "
              'covering. Their planned schedule is preserved.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: blocksAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "Could not load this cohort's blocks.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ),
                data: (blocks) {
                  // Bucket blocks by their planned lead. Blocks with
                  // no planned lead can't be "covered" — there's no
                  // absent person to cover for — so we filter them.
                  final byLead = <String, List<ScheduleBlock>>{};
                  for (final b in blocks) {
                    final lead = b.leadMemberId;
                    if (lead == null || lead.isEmpty) continue;
                    byLead.putIfAbsent(lead, () => <ScheduleBlock>[]).add(b);
                  }
                  if (byLead.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        "No blocks have a lead assigned yet — there's "
                        'nothing to cover. Assign leads on each block '
                        'first.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  // Sort: uncovered first (action items), then by name
                  // for stability.
                  final entries = byLead.entries.toList()
                    ..sort((a, b) {
                      final aCov = a.value.first.leadSubstituteMemberId != null;
                      final bCov = b.value.first.leadSubstituteMemberId != null;
                      if (aCov != bCov) return aCov ? 1 : -1;
                      final aName =
                          memberById[a.key]?.displayName ?? '';
                      final bName =
                          memberById[b.key]?.displayName ?? '';
                      return aName.compareTo(bName);
                    });

                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final lead = memberById[e.key];
                      final blocksForLead = e.value;
                      // All blocks for a single planned lead share the
                      // same substitute value (the DAO updates them in
                      // bulk), but read defensively from the first row.
                      final subId =
                          blocksForLead.first.leadSubstituteMemberId;
                      final sub = subId == null ? null : memberById[subId];
                      return _LeadRow(
                        leadName: lead?.displayName ?? 'Unknown',
                        blockCount: blocksForLead.length,
                        substituteName: sub?.displayName,
                        onCover: () => unawaited(_coverLead(
                          context: context,
                          ref: ref,
                          leadId: e.key,
                          leadName: lead?.displayName ?? 'Unknown',
                          blockCount: blocksForLead.length,
                          allMembers: members,
                          excludeIds: {e.key},
                        )),
                        onRestore: subId == null
                            ? null
                            : () => unawaited(_restoreLead(
                                  context: context,
                                  ref: ref,
                                  leadId: e.key,
                                  leadName: lead?.displayName ?? 'Unknown',
                                )),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _coverLead({
    required BuildContext context,
    required WidgetRef ref,
    required String leadId,
    required String leadName,
    required int blockCount,
    required List<Member> allMembers,
    required Set<String> excludeIds,
  }) async {
    final substitute = await showGlassSheet<Member>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SubstitutePickerSheet(
        absentName: leadName,
        candidates: allMembers
            .where((m) => !excludeIds.contains(m.id))
            .toList(growable: false),
      ),
    );
    if (substitute == null) return;
    if (!context.mounted) return;
    final actions = ref.read(scheduleActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final affected = await actions.coverLeadForDay(
        groupId: groupId,
        date: date,
        absentMemberId: leadId,
        substituteMemberId: substitute.id,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            affected == 1
                ? '${substitute.displayName} is covering 1 block for $leadName.'
                : '${substitute.displayName} is covering $affected blocks for $leadName.',
          ),
        ),
      );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'schedule'),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't set the substitute.")),
      );
    }
  }

  Future<void> _restoreLead({
    required BuildContext context,
    required WidgetRef ref,
    required String leadId,
    required String leadName,
  }) async {
    final actions = ref.read(scheduleActionsProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await actions.coverLeadForDay(
        groupId: groupId,
        date: date,
        absentMemberId: leadId,
        substituteMemberId: null,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Restored $leadName as the lead for their blocks today.',
          ),
        ),
      );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'schedule'),
      );
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't restore the lead.")),
      );
    }
  }
}

class _LeadRow extends StatelessWidget {
  const _LeadRow({
    required this.leadName,
    required this.blockCount,
    required this.substituteName,
    required this.onCover,
    required this.onRestore,
  });

  final String leadName;
  final int blockCount;
  final String? substituteName;
  final VoidCallback onCover;

  /// Null disables the restore action (no substitute set).
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final covered = substituteName != null;
    return Material(
      color: covered
          ? scheme.tertiaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leadName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: covered
                          ? scheme.onTertiaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    covered
                        ? 'Covered by $substituteName · '
                            '${_plural(blockCount, "block", "blocks")}'
                        : '${_plural(blockCount, "block", "blocks")} '
                            'today',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: covered
                          ? scheme.onTertiaryContainer
                              .withValues(alpha: 0.85)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (covered)
              TextButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.undo, size: 18),
                label: const Text('Restore'),
              )
            else
              FilledButton.tonalIcon(
                onPressed: onCover,
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Cover'),
              ),
          ],
        ),
      ),
    );
  }

  static String _plural(int n, String one, String many) =>
      n == 1 ? '1 $one' : '$n $many';
}

class _SubstitutePickerSheet extends ConsumerWidget {
  const _SubstitutePickerSheet({
    required this.absentName,
    required this.candidates,
  });

  final String absentName;
  final List<Member> candidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final vertical = ref.watch(verticalLabelsProvider).vertical;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Who's covering for $absentName?",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No other staff in this space to cover.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final m = candidates[i];
                    return ListTile(
                      title: Text(m.displayName),
                      subtitle: Text(_roleLabel(m.role, vertical: vertical)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(m),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Short label so the row doesn't shout role keys at users.
  /// Routes through `RoleLabels.of` so non-childcare verticals get
  /// their own labels (construction "Foreman", healthcare "RN", …).
  static String _roleLabel(String role, {required String vertical}) {
    return RoleLabels.of(role, vertical: vertical);
  }
}
