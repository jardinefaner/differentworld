import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/messages` for the family lens — one row per child the guardian
/// is linked to, with the latest message preview + unread count. Tap
/// a row to open that child's thread.
///
/// Solves the "guardian has 2+ kids" gap: the omnibox previously
/// dropped them straight into the first child's thread. Now it lands
/// here so they can pick.
class FamilyMessagesScreen extends ConsumerWidget {
  const FamilyMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (viewer is! GuardianViewer) {
      // Staff don't have a global messages index — they reach threads
      // from each kid's detail. Defensive empty state for the rare
      // case a staff member hits this URL.
      return const EdgeScaffold(
        body: EmptyState(
          icon: Icons.forum_outlined,
          title: 'No global messages view',
          message:
              "Staff reach threads from each child's detail screen.",
        ),
      );
    }
    final childrenAsync = ref.watch(familyChildrenProvider);
    final allMessages =
        ref.watch(myGuardianMessagesProvider).value ?? const <Message>[];

    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: childrenAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load',
          onRetry: () => ref.invalidate(familyChildrenProvider),
        ),
        data: (children) {
          if (children.isEmpty) {
            return const EmptyState(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              message:
                  'Your program director will link your child to your '
                  'account; once they do, message threads will appear here.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Messages',
                  subtitle:
                      'A direct line between you and the team — one '
                      'thread per child.',
                ),
              ),
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: _ChildThreadCard(
                    child: child,
                    guardianId: viewer.guardian.id,
                    allMessages: allMessages,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ChildThreadCard extends StatelessWidget {
  const _ChildThreadCard({
    required this.child,
    required this.guardianId,
    required this.allMessages,
  });

  final Subject child;
  final String guardianId;
  final List<Message> allMessages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = allMessages
        .where((m) => m.subjectId == child.id && m.guardianId == guardianId)
        .toList();
    final unread = mine
        .where(
            (m) => m.senderKind == MessageSenderKind.staff && m.readAt == null)
        .length;
    final latest = mine.isEmpty ? null : mine.first;
    final fullName = '${child.firstName} ${child.lastName}'.trim();

    return FeatureCard(
      leading: PersonAvatar(
        name: fullName,
        photoUrl: child.photoUrl,
        radius: 22,
      ),
      onTap: () => context.push('/messages/${child.id}/$guardianId'),
      title: Row(
        children: [
          Expanded(
            child: Text(
              fullName,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (latest != null)
            Text(
              relativeTimeAgo(
                DateTime.tryParse(latest.createdAt)?.toLocal(),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      subtitle: Text(
        latest?.body ?? 'No messages yet — tap to start.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: latest == null ? FontStyle.italic : null,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: unread > 0
          ? Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : null,
    );
  }
}
