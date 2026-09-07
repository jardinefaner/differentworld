import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/today/needs_you.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What needs you now — at most three, ranked, or nothing at all.
///
/// Renders NOTHING when the list is empty. That is the whole difference from
/// the tiles it sits above: "Captures — all clear" occupies the top of the
/// screen to tell a staffer that nothing is happening, which is a sign on a
/// wall. This gives the space back to the room.
class NeedsYouCard extends ConsumerWidget {
  const NeedsYouCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(needsYouListProvider);
    // A FAILED read must not render as "nothing needs you" — that is the
    // swallowed-error trap, and here it would tell a staffer the room is fine
    // when the app simply cannot see it.
    if (list.hasError) {
      return const _Line(
        urgency: Urgency.attention,
        what: "Can't check the rooms right now",
        detail: 'Attendance and the day board are still loading',
        onTap: null,
      );
    }
    final items = list.value ?? const <Priority>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in items) ...[
            _Line(
              urgency: p.urgency,
              what: p.what,
              detail: p.detail,
              onTap: () => unawaited(context.push(p.route)),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.urgency,
    required this.what,
    required this.detail,
    required this.onTap,
  });

  final Urgency urgency;
  final String what;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = theme.extension<AppColors>();
    // Ranked by colour as well as order, so the top of the list reads as the
    // top of the list at a glance. Error red is reserved for a child nobody
    // has accounted for — nothing else on this screen earns it.
    final edge = switch (urgency) {
      Urgency.child => scheme.error,
      Urgency.attention => scheme.tertiary,
      Urgency.note => app?.growth ?? scheme.primary,
    };
    return Material(
      color: scheme.surfaceContainerHighest,
      // One left edge, rounded on the right — BRAND.md law 1, the same shape
      // ActivityPrompt and the cast device cards use.
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(18),
        bottomRight: Radius.circular(18),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: edge, width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(what, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
