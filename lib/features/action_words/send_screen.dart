import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/parent_message.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The brief's SEND screen — end of day, each kid's auto-generated parent
/// message with a Copy button (paste into text / WhatsApp). v1 is a copy
/// surface, not a messaging system.
class SendScreen extends ConsumerWidget {
  const SendScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: subjectsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load children',
          onRetry: () => ref.invalidate(subjectsInSpaceProvider),
        ),
        data: (subjects) {
          if (subjects.isEmpty) {
            return const EmptyState(
              icon: Icons.outgoing_mail,
              title: 'No children yet',
              message: 'Pick each child’s words for the day, then send '
                  'families a note from here.',
            );
          }
          return ResponsivePage(
            children: [
              const ContentHeader(
                title: 'Send home',
                subtitle: 'Tap Copy, then paste into your messaging app.',
              ),
              for (final s in subjects)
                _SendCard(key: ValueKey(s.id), subject: s),
            ],
          );
        },
      ),
    );
  }
}

class _SendCard extends ConsumerWidget {
  const _SendCard({required this.subject, super.key});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final day = ref
        .watch(actionWordsForDayProvider(
          (subjectId: subject.id, date: todayKey()),
        ))
        .value;
    // Only children with picks today have a message to send.
    if (day == null || !day.hasPicks) return const SizedBox.shrink();

    final fullName = '${subject.firstName} ${subject.lastName}'.trim();
    final message = buildParentMessage(childName: subject.firstName, day: day);
    final emoji = day.world?.world?.emoji ?? '🌟';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fullName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                message,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  unawaited(HapticFeedback.selectionClick());
                  await Clipboard.setData(ClipboardData(text: message));
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Copied ${subject.firstName}’s message'),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
