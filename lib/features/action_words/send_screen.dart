import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/parent_message.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). The send-home note is TEXT-HEAVY (a multi-line
    // parent message each card shows + copies), so the bento variant keeps the
    // cards FULL-WIDTH on a phone for readability and only packs them 2-up on a
    // tablet/desktop where two messages read side by side. Same subjects, same
    // per-child message + Copy, same self-filtering (only kids with picks
    // today render).
    final bento = bentoEnabled(ref, perScreen: null);
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
              if (bento)
                _SendGrid(subjects: subjects)
              else
                for (final s in subjects)
                  _SendCard(key: ValueKey(s.id), subject: s),
            ],
          );
        },
      ),
    );
  }
}

/// The bento variant — the SAME children, re-laid as a responsive [Wrap] of
/// send-home cards. The message body is text-heavy, so cards stay FULL-WIDTH on
/// a phone (one readable column) and pack 2-up only at tablet/desktop width
/// where two messages fit side by side. A [Wrap] (not a [GridView]) is used on
/// purpose: each [_SendCard] self-filters to `SizedBox.shrink()` when the child
/// has no picks today, and a Wrap absorbs a zero-size child gracefully where a
/// fixed grid would leave a hole. Each card carries a stable [ValueKey].
class _SendGrid extends StatelessWidget {
  const _SendGrid({required this.subjects});

  final List<Subject> subjects;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final width = constraints.maxWidth;
        // 2-up once there's room for two readable message columns; 1-up on a
        // phone so the parent note never squeezes into an unreadable ribbon.
        final twoUp = width >= 720;
        final cardWidth = twoUp ? (width - gap) / 2 : width;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in subjects)
              _SendCard(
                key: ValueKey('send-${s.id}'),
                subject: s,
                // The card applies this width itself ONLY when it has a message
                // to show; a child with no picks returns a bare zero-size
                // SizedBox so it claims no slot in the Wrap run (keeping 2-up
                // pairing intact). embedded → drop the card's own margin.
                width: cardWidth,
                embedded: true,
              ),
          ],
        );
      },
    );
  }
}

class _SendCard extends ConsumerWidget {
  const _SendCard({
    required this.subject,
    this.width,
    this.embedded = false,
    super.key,
  });

  final Subject subject;

  /// In the bento [Wrap] the card sizes itself to this width — but ONLY on the
  /// content path. A child with no picks returns a bare zero-size SizedBox so
  /// it claims no slot in the Wrap run.
  final double? width;

  /// In the bento variant the Wrap's runSpacing owns vertical spacing, so the
  /// card drops its own bottom margin.
  final bool embedded;

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
    final match = resolveWorld(
      day.verbPicks.toSet(),
      ref.watch(classWorldBookProvider),
    );
    final message = buildParentMessage(
      childName: subject.firstName,
      day: day,
      world: match,
    );
    final emoji = match.world?.emoji ?? '🌟';

    final card = Card(
      margin: embedded ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
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

    // In the bento Wrap the card sizes to its column; in the flat list it fills
    // the page width as before.
    return width == null ? card : SizedBox(width: width, child: card);
  }
}
