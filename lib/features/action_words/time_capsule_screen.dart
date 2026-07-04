import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/time_capsule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// `/time-capsules` — **time capsules** (docs/WORLD.md — Week 8 "seal in a
/// box, open Week 10"). Bury a note sealed until a date; it stays locked
/// (contents hidden) until that day comes. New `time_capsule` entries; no
/// table.
class TimeCapsuleScreen extends ConsumerWidget {
  const TimeCapsuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capsulesAsync = ref.watch(timeCapsulesProvider);
    final now = DateTime.now();
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the short capsule cards re-lay as a
    // dense 2-up grid (on a phone) over the SAME provider data; off keeps the
    // existing single-column list.
    final bento = bentoEnabled(ref, perScreen: null);

    return EdgeScaffold(
      actions: [
        PrimaryActionButton(
          tooltip: 'Bury a capsule',
          icon: Icons.add,
          onPressed: () => _bury(context, ref),
        ),
      ],
      body: capsulesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.lock_clock_outlined,
          title: 'Time capsules',
          message: 'Could not load them right now.',
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return EmptyState(
              icon: Icons.lock_clock_outlined,
              title: 'No capsules yet',
              message:
                  'Seal a note, a wish, a message to the future — it '
                  'stays locked until the day you choose.',
              action: FilledButton.icon(
                onPressed: () => _bury(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Bury a capsule'),
              ),
            );
          }
          final capsules = sortCapsules(entries, now);
          return bento
              ? _bentoBody(context, ref, capsules, now)
              : _flatBody(context, ref, capsules, now);
        },
      ),
    );
  }

  /// The default layout — header + a single-column list of capsule cards.
  Widget _flatBody(
    BuildContext context,
    WidgetRef ref,
    List<TimeCapsule> capsules,
    DateTime now,
  ) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'Time capsules',
          subtitle: 'Sealed until the day comes',
        ),
        for (final c in capsules)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CapsuleCard(
              capsule: c,
              sealed: c.sealedAt(now),
              onDelete: () => _delete(context, ref, c),
            ),
          ),
      ],
    );
  }

  /// The bento variant — SAME capsules, re-laid as a dense responsive grid.
  /// The header stays full-width; the short capsule cards pack into a
  /// `GridView.builder` that's 2-up on a phone (≈180dp cells), more across
  /// wider screens. A program's capsules are a small bounded set, so a
  /// shrink-wrapped grid (the wall/present pattern) is fine — the builder
  /// still constructs cells on demand.
  Widget _bentoBody(
    BuildContext context,
    WidgetRef ref,
    List<TimeCapsule> capsules,
    DateTime now,
  ) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'Time capsules',
          subtitle: 'Sealed until the day comes',
        ),
        GridView.builder(
          shrinkWrap: true,
          primary: false,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            // Capsule cards grow with their text; a generous min keeps the
            // 2-up phone cells from clipping the sealed/opened body + date.
            mainAxisExtent: 132,
          ),
          itemCount: capsules.length,
          itemBuilder: (context, i) {
            final c = capsules[i];
            return _CapsuleCard(
              key: ValueKey('capsule-${c.id}'),
              capsule: c,
              sealed: c.sealedAt(now),
              onDelete: () => _delete(context, ref, c),
            );
          },
        ),
      ],
    );
  }

  Future<void> _bury(BuildContext context, WidgetRef ref) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _BurySheet(),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TimeCapsule c,
  ) async {
    // `restore` re-inserts the whole row, so capture the full Entry (matched by
    // id from the same provider the screen watches) before deleting.
    Entry? entry;
    for (final e in ref.read(timeCapsulesProvider).value ?? const <Entry>[]) {
      if (e.id == c.id) {
        entry = e;
        break;
      }
    }
    if (entry == null) {
      await ref.read(entryActionsProvider).delete(c.id);
      return;
    }
    final row = entry;
    await deleteWithUndo(
      context,
      label: 'time capsule',
      onDelete: () => ref.read(entryActionsProvider).delete(row.id),
      onUndo: () => ref.read(entryActionsProvider).restore(row),
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  const _CapsuleCard({
    required this.capsule,
    required this.sealed,
    required this.onDelete,
    super.key,
  });
  final TimeCapsule capsule;
  final bool sealed;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final until = capsule.sealedUntil;
    final dateLabel = until == null ? '' : DateFormat.yMMMMd().format(until);
    // Bottom spacing is owned by the caller — a `Padding` wrapper in the flat
    // list, the grid cell gap in the bento variant. The card itself just
    // fills the width / height it's handed (the grid caps the height, so the
    // body flexes + ellipsises; the flat list lets it size intrinsically).
    return GestureDetector(
      onLongPress: () => unawaited(onDelete()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: sealed
              ? theme.colorScheme.surfaceContainerHighest
              : theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              sealed ? Icons.lock_outline : Icons.lock_open,
              color: sealed
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onTertiaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: sealed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sealed', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(
                          'Opens $dateLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            capsule.text,
                            style: theme.textTheme.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Opened${dateLabel.isEmpty ? '' : ' · sealed $dateLabel'}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer
                                .withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BurySheet extends ConsumerStatefulWidget {
  const _BurySheet();

  @override
  ConsumerState<_BurySheet> createState() => _BurySheetState();
}

class _BurySheetState extends ConsumerState<_BurySheet> {
  final _text = TextEditingController();
  late DateTime _until = DateTime.now().add(const Duration(days: 14));

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Bury a time capsule', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'A message to the future — what do you hope?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  // Dismiss the keyboard intentionally before the picker
                  // dialog steals focus (interaction rule #5).
                  FocusScope.of(context).unfocus();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _until,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 400)),
                    helpText: 'Open the capsule on',
                  );
                  if (picked != null && mounted) {
                    setState(() => _until = picked);
                  }
                },
                icon: const Icon(Icons.event, size: 18),
                label: Text('Opens ${DateFormat.yMMMMd().format(_until)}'),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  final text = _text.text.trim();
                  if (text.isEmpty) return;
                  final nav = Navigator.of(context);
                  await ref
                      .read(entryActionsProvider)
                      .createTimeCapsule(
                        text: text,
                        sealedUntil: _until,
                      );
                  if (!mounted) return;
                  nav.pop();
                },
                child: const Text('Seal it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
