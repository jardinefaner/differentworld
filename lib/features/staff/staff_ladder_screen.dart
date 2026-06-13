import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/staff/staff_ladder.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
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
    return EdgeScaffold(
      body: rolesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load the ladder',
          onRetry: () => ref.invalidate(staffRolesProvider),
        ),
        data: (roles) {
          StaffRole? mine;
          for (final r in roles) {
            if (r.id == myLevel) {
              mine = r;
              break;
            }
          }
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
        },
      ),
    );
  }
}

class _CurrentRung extends StatelessWidget {
  const _CurrentRung({required this.role});
  final StaffRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
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
  });

  final StaffRole role;
  final int rung;
  final bool isMine;
  final VoidCallback onMarkMine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 10),
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
            Text(
              role.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
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
