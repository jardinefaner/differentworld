import 'dart:async';
import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/staff/staff_ladder.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/staff` — **the staff growth ladder.** Shadow → Extra Hands → Co-Pilot →
/// Conductor, each with what it can do and what it can't do YET. You mark
/// where you are (a local growth reflection, not a permission gate). Mirrors
/// the kid's own character arc.
class StaffLadderScreen extends ConsumerWidget {
  const StaffLadderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(staffRolesProvider);
    final myLevel = ref.watch(staffLevelProvider).value;
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). The ladder is TEXT-HEAVY (each rung expands to a
    // description + "Can do" / "Not yet" lists), so the bento variant keeps the
    // rungs FULL-WIDTH — a 2-up grid would clip the inline ExpansionTile. What
    // bento changes: the current rung leads as a hero banner and the rungs +
    // see-also become bento tiles, inheriting the system grid + keys. Same
    // roles, same "This is me" tap, same expand-in-place behaviour.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      body: rolesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the ladder',
          onRetry: () => ref.invalidate(staffRolesProvider),
        ),
        data: (roles) {
          if (roles.isEmpty) {
            return const EmptyState(
              icon: Icons.school_outlined,
              title: 'No ladder to show',
              message: 'The staff growth ladder could not be loaded.',
            );
          }
          StaffRole? mine;
          for (final r in roles) {
            if (r.id == myLevel) {
              mine = r;
              break;
            }
          }
          return bento
              ? _bentoBody(ref, roles, myLevel, mine)
              : _flatBody(ref, roles, myLevel, mine);
        },
      ),
    );
  }

  /// The default layout — the current-rung banner + the rungs as a vertical
  /// stack of expanding cards.
  Widget _flatBody(
    WidgetRef ref,
    List<StaffRole> roles,
    String? myLevel,
    StaffRole? mine,
  ) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'The staff ladder',
          subtitle: 'You climb by practice, not by time',
        ),
        if (mine != null) _CurrentRung(role: mine),
        for (var i = 0; i < roles.length; i++)
          _RoleCard(
            role: roles[i],
            rung: i + 1,
            isMine: roles[i].id == myLevel,
            onMarkMine: () => unawaited(
              ref.read(staffLevelProvider.notifier).set(roles[i].id),
            ),
          ),
        const SizedBox(height: 8),
        _SeeAlso(),
      ],
    );
  }

  /// The bento variant — the SAME rungs as modular tiles. The current rung
  /// leads as a hero; the rungs stay full-width (they expand in place, so they
  /// can't shrink into a 2-up cell) but flow through [BentoGrid] so the screen
  /// reads as the system. The rung tiles are min-height — the ExpansionTile
  /// grows past the floor (never a fixed box; no `Spacer`/`Expanded` inside, so
  /// the unbounded-max cell is safe — see docs/GRID.md).
  Widget _bentoBody(
    WidgetRef ref,
    List<StaffRole> roles,
    String? myLevel,
    StaffRole? mine,
  ) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'The staff ladder',
          subtitle: 'You climb by practice, not by time',
        ),
        BentoGrid(
          tiles: [
            if (mine != null)
              BentoTile(
                id: 'current-rung',
                span: const BentoSpan.wide(rows: 2),
                child: _CurrentRung(role: mine, embedded: true),
              ),
            for (var i = 0; i < roles.length; i++)
              BentoTile(
                id: 'rung-${roles[i].id}',
                span: const BentoSpan.wide(),
                child: _RoleCard(
                  role: roles[i],
                  rung: i + 1,
                  isMine: roles[i].id == myLevel,
                  embedded: true,
                  onMarkMine: () => unawaited(
                    ref.read(staffLevelProvider.notifier).set(roles[i].id),
                  ),
                ),
              ),
            BentoTile(
              id: 'see-also',
              span: const BentoSpan.wide(),
              child: _SeeAlso(),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurrentRung extends StatelessWidget {
  const _CurrentRung({required this.role, this.embedded = false});
  final StaffRole role;

  /// In the bento variant the tile + grid gap own the spacing, so the banner
  /// drops its own bottom margin.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: embedded ? EdgeInsets.zero : const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(role.emoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOU ARE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  role.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  role.desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.85,
                    ),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.rung,
    required this.isMine,
    required this.onMarkMine,
    this.embedded = false,
  });

  final StaffRole role;
  final int rung;
  final bool isMine;
  final VoidCallback onMarkMine;

  /// In the bento variant the tile + grid gap own the spacing, so the card
  /// drops its own bottom margin (it fills its full-width tile).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: embedded ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isMine
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ExpansionTile(
        initiallyExpanded: isMine,
        leading: Text(role.emoji, style: const TextStyle(fontSize: 26)),
        title: Row(
          children: [
            Flexible(
              child: Text(
                role.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isMine) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
        subtitle: Text(
          'Rung $rung · ${role.duration}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role.desc,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 12),
          _ListBlock(
            label: 'Can do',
            items: role.canDo,
            tone: AppColors.growthOf(theme),
          ),
          if (role.cantDo.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ListBlock(
              label: 'Not yet',
              items: role.cantDo,
              tone: theme.colorScheme.onSurfaceVariant,
              muted: true,
            ),
          ],
          const SizedBox(height: 12),
          if (!isMine)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onMarkMine,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('This is me'),
              ),
            )
          else
            Text(
              'This is where you are today.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

class _ListBlock extends StatelessWidget {
  const _ListBlock({
    required this.label,
    required this.items,
    required this.tone,
    this.muted = false,
  });

  final String label;
  final List<String> items;
  final Color tone;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: tone,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  muted ? '○  ' : '✓  ',
                  style: TextStyle(color: tone, height: 1.4),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: muted
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SeeAlso extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GROW THROUGH',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/runbook'),
              icon: const Icon(Icons.menu_book_outlined, size: 18),
              label: const Text('The runbook'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/verb-jobs'),
              icon: const Icon(Icons.workspace_premium_outlined, size: 18),
              label: const Text('Verb skills'),
            ),
          ],
        ),
      ],
    );
  }
}
