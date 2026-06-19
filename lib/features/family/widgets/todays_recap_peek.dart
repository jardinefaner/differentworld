import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/recap/recap_model.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Today's recap, on the family lens — the room's shared day + this child's own
/// moments, from the per-child recap entry staff send (already scrubbed of other
/// children's names; see recap_model.dart). Renders nothing until today's recap
/// is sent, so the child card stays tight on a quiet morning.
class TodaysRecapPeek extends ConsumerWidget {
  const TodaysRecapPeek({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref
            .watch(
              familyEntriesForSubjectProvider((
                subjectId: subjectId,
                kind: EntryKind.recap,
              )),
            )
            .value ??
        const <Entry>[];
    if (entries.isEmpty) return const SizedBox.shrink();
    final today = todayKey();
    RecapView? view;
    for (final e in entries) {
      try {
        final parsed = RecapView.fromJson(
          jsonDecode(e.details) as Map<String, dynamic>,
        );
        if (parsed.date == today) {
          view = parsed;
          break;
        }
      } on Object {
        // A malformed recap row just doesn't render.
      }
    }
    final v = view;
    if (v == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _RecapPeekCard(view: v),
    );
  }
}

/// The recap card itself — a left-edge tinted panel: the room's day, the
/// optional moment, then this child's own moments (their answer + hero).
class _RecapPeekCard extends StatelessWidget {
  const _RecapPeekCard({required this.view});

  final RecapView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(left: BorderSide(color: scheme.primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'today’s recap',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (view.activities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in view.activities)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(a, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ],
          if (view.moment != null && view.moment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(view.moment!, style: theme.textTheme.bodyMedium),
          ],
          if (view.question != null && view.question!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              view.question!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (view.answer != null && view.answer!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '“${view.answer}”',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          if (view.heroName != null && view.heroName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.shield_moon_outlined,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${view.childName}’s hero today: ${view.heroName}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
