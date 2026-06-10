import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/guardians/guardians_providers.dart';
import 'package:differentworld/features/pickup/pickup_board_providers.dart';
import 'package:differentworld/features/pickup/pickup_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:differentworld/shared/widgets/section_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The dismissal board — the pickup-rush counterpart to the morning
/// checklist (docs/WORKFLOWS.md gap #2). One cross-program view of who's
/// still in the building, one tap to release each child to an authorized
/// person, and an undo for the misfire. Reads attendance (who's here)
/// and `entries.kind='departure'` (who's left) — no new data layer.
class PickupBoardScreen extends ConsumerWidget {
  const PickupBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(pickupBoardProvider);
    final labels = ref.watch(verticalLabelsProvider);
    final canRelease = ref.watch(viewerProvider).canTakeAttendance;
    final kids = labels.subjectPlural.toLowerCase();

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: boardAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load pickup',
          onRetry: () => ref.invalidate(pickupBoardProvider),
        ),
        data: (board) {
          if (board.isEmpty) {
            return EmptyState(
              icon: Icons.directions_walk_outlined,
              title: 'No one to release yet',
              message: 'Mark $kids present in attendance and they’ll appear '
                  'here at pickup time — one tap to release each one.',
            );
          }
          return ResponsivePage(
            children: [
              ContentHeader(
                title: 'Pickup',
                subtitle: _subtitle(board),
              ),
              if (board.stillHere.isEmpty)
                _AllClearCard(count: board.releasedCount, kids: kids)
              else
                for (final e in board.stillHere)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StillHereRow(entry: e, canRelease: canRelease),
                  ),
              const SizedBox(height: 12),
              SectionCard(
                visible: board.released.isNotEmpty,
                icon: Icons.check_circle_outline,
                title: 'Picked up today',
                child: Column(
                  children: [
                    for (final e in board.released)
                      _ReleasedRow(entry: e, canRelease: canRelease),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _subtitle(PickupBoard board) {
    final here = board.hereCount;
    final gone = board.releasedCount;
    if (here == 0) return gone == 1 ? '1 picked up' : 'All $gone picked up';
    final herePart = here == 1 ? '1 still here' : '$here still here';
    if (gone == 0) return herePart;
    return '$herePart · $gone picked up';
  }
}

/// A child still in the building: tap (or the Release button) to hand
/// them to an authorized pickup person.
class _StillHereRow extends ConsumerWidget {
  const _StillHereRow({required this.entry, required this.canRelease});

  final PickupBoardEntry entry;
  final bool canRelease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: PersonAvatar(
          name: entry.fullName,
          photoUrl: entry.subject.photoUrl,
        ),
        title: Text(entry.fullName),
        subtitle: Text(
          entry.group.name,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: canRelease
            ? FilledButton.tonalIcon(
                onPressed: () => _openRelease(context, ref, entry),
                icon: const Icon(Icons.directions_walk, size: 18),
                label: const Text('Release'),
              )
            : null,
        onTap: canRelease ? () => _openRelease(context, ref, entry) : null,
      ),
    );
  }
}

/// A child already picked up today — shows who they went to + when, with
/// an undo for mistakes.
class _ReleasedRow extends ConsumerWidget {
  const _ReleasedRow({required this.entry, required this.canRelease});

  final PickupBoardEntry entry;
  final bool canRelease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dep = entry.departure;
    final when = dep == null ? null : DateTime.tryParse(dep.recordedAt)?.toLocal();
    final to = (dep?.body ?? '').trim();
    final String subtitle;
    if (entry.leftEarly) {
      subtitle = 'Left early';
    } else {
      final parts = <String>[
        if (to.isNotEmpty) 'to $to',
        if (when != null) timeOfDay(when),
      ];
      subtitle = parts.isEmpty ? 'Picked up' : parts.join(' · ');
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Opacity(
        opacity: 0.6,
        child: PersonAvatar(
          name: entry.fullName,
          photoUrl: entry.subject.photoUrl,
        ),
      ),
      title: Text(entry.fullName),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      // Only board releases (which carry a departure entry) can be undone;
      // an early_pickup is an attendance fact, edited in attendance.
      trailing: canRelease && dep != null
          ? TextButton(
              onPressed: () {
                // Optimistic + fire-and-forget: the delete is a local
                // Drift write, so there's no await gap that could leave a
                // snackbar firing on a dead context.
                final messenger = ScaffoldMessenger.of(context);
                unawaited(HapticFeedback.selectionClick());
                unawaited(ref.read(pickupBoardActionsProvider).undo(dep.id));
                messenger.showSnackBar(
                  SnackBar(content: Text('${entry.fullName} back on the board')),
                );
              },
              child: const Text('Undo'),
            )
          : null,
    );
  }
}

/// Shown in place of the still-here list when everyone's been picked up.
class _AllClearCard extends StatelessWidget {
  const _AllClearCard({required this.count, required this.kids});

  final int count;
  final String kids;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Row(
          children: [
            Icon(
              Icons.celebration_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                count == 1
                    ? 'That’s a wrap — everyone’s been picked up.'
                    : 'That’s a wrap — all $count picked up and accounted for.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openRelease(
  BuildContext context,
  WidgetRef ref,
  PickupBoardEntry entry,
) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ReleaseSheet(entry: entry),
  );
}

/// "Who's picking up {name}?" — the authorized people (formal guardians
/// flagged for pickup + the extra pickup people on file), each a one-tap
/// release, plus a "Someone else" fallback the staff verifies in person.
class _ReleaseSheet extends ConsumerStatefulWidget {
  const _ReleaseSheet({required this.entry});

  final PickupBoardEntry entry;

  @override
  ConsumerState<_ReleaseSheet> createState() => _ReleaseSheetState();
}

class _ReleaseSheetState extends ConsumerState<_ReleaseSheet> {
  // Guards the whole sheet against a double-tap (or a second tile tapped
  // before the pop): without it, two departure entries land for the same
  // child and the sheet pops twice — the second pop ejects staff off the
  // board. One release per sheet, one pop.
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final theme = Theme.of(context);
    final guardiansAsync = ref.watch(
      guardiansForSubjectProvider(entry.subject.id),
    );
    final guardians = (guardiansAsync.value ?? const <Guardian>[])
        .where((g) => (g.authorizedForPickup ?? 0) == 1)
        .toList(growable: false);
    final extra = pickupPeopleFor(entry.subject);
    final hasAnyAuthorized = guardians.isNotEmpty || extra.isNotEmpty;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GlassDragHandle(bottomMargin: 16),
              Text(
                'Release ${entry.fullName}',
                style: theme.textTheme.titleLarge,
              ),
              Text(
                'Who’s picking up?',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (!hasAnyAuthorized)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No authorized pickup people on file. Verify identity '
                    'before releasing.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final g in guardians)
                _ChoiceTile(
                  name: g.name,
                  detail: [
                    g.relationship,
                    g.phone,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  icon: Icons.verified_user_outlined,
                  onTap: () => _release(releasedTo: g.name, guardianId: g.id),
                ),
              for (final p in extra)
                _ChoiceTile(
                  name: p.name,
                  detail: [
                    p.phone,
                    p.notes,
                  ].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                  icon: Icons.person_outline,
                  onTap: () => _release(releasedTo: p.name),
                ),
              _ChoiceTile(
                name: 'Someone else',
                detail: 'Verify in person',
                icon: Icons.more_horiz,
                onTap: () => _release(releasedTo: 'Someone else'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _release({
    required String releasedTo,
    String? guardianId,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final entry = widget.entry;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    unawaited(HapticFeedback.selectionClick());
    final ok = await ref.read(pickupBoardActionsProvider).release(
          subjectId: entry.subject.id,
          groupId: entry.group.id,
          releasedTo: releasedTo,
          guardianId: guardianId,
        );
    if (!mounted) return;
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Released ${entry.fullName} to $releasedTo'
              : 'Couldn’t release — sign in again and retry.',
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.name,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String name;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(icon, color: theme.colorScheme.onSecondaryContainer),
        ),
        title: Text(name),
        subtitle: detail.isEmpty ? null : Text(detail),
        trailing: const Icon(Icons.directions_walk, size: 18),
        onTap: onTap,
      ),
    );
  }
}
