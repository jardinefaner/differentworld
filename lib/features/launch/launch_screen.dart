import 'package:differentworld/features/launch/launch_readiness.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/ready` — **ready to run tomorrow?** The setup state is scattered across
/// the journey, the roster, and the schedule; this composes the real
/// preconditions into one checklist so a teacher knows what's still undone
/// before 9:00. Each unmet item carries the fix one tap away.
class LaunchScreen extends ConsumerWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = ref.watch(launchReadinessProvider);
    final ready = allReady(items);
    final count = readyCount(items);
    return EdgeScaffold(
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Ready to run',
            subtitle: 'What you need before tomorrow morning',
          ),
          // The verdict.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            decoration: BoxDecoration(
              color: ready
                  ? const Color(0xFF51CF66).withValues(alpha: 0.12)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  ready ? Icons.check_circle : Icons.pending_outlined,
                  color: ready
                      ? const Color(0xFF2F9E44)
                      : theme.colorScheme.onSurfaceVariant,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ready
                            ? "You're ready to run tomorrow."
                            : '${count.done} of ${count.total} ready',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ready
                            ? 'Print the basket tonight and open Today at 9:00.'
                            : 'A couple of things left — each is one tap.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final item in items) _ReadyRow(item: item),
        ],
      ),
    );
  }
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({required this.item});
  final ReadyItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, tone) = switch (item.status) {
      ReadyStatus.done => (Icons.check_circle, const Color(0xFF2F9E44)),
      ReadyStatus.todo => (
        Icons.radio_button_unchecked,
        theme.colorScheme.primary,
      ),
      ReadyStatus.info => (
        Icons.info_outline,
        theme.colorScheme.onSurfaceVariant,
      ),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, color: tone, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (item.why.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.why,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (item.actionLabel != null && item.actionRoute != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () => context.push(item.actionRoute!),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Text(item.actionLabel!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
