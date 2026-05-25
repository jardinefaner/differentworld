
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/guardians/guardians_providers.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GuardiansList extends ConsumerWidget {
  const GuardiansList({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final guardiansAsync = ref.watch(guardiansForSubjectProvider(subjectId));
    return guardiansAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          'Could not load family.',
          style: theme.textTheme.bodySmall,
        ),
      ),
      data: (guardians) {
        if (guardians.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'No guardians on file.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Column(
          children: [
            for (final g in guardians)
              _GuardianRow(subjectId: subjectId, guardian: g),
          ],
        );
      },
    );
  }
}

class _GuardianRow extends ConsumerWidget {
  const _GuardianRow({required this.subjectId, required this.guardian});

  final String subjectId;
  final Guardian guardian;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final messagesAsync = ref.watch(messageThreadProvider(
      (subjectId: subjectId, guardianId: guardian.id),
    ));
    final messages = messagesAsync.value ?? const <Message>[];
    final unread = messages
        .where((m) =>
            m.senderKind == MessageSenderKind.guardian && m.readAt == null)
        .length;

    return ListTile(
      leading: PersonAvatar(name: guardian.name),
      title: Text(guardian.name),
      subtitle: Text(
        [
          guardian.relationship,
          guardian.phone,
          guardian.email,
        ].whereType<String>().join(' · '),
      ),
      trailing: IconButton(
        tooltip: unread > 0
            ? '$unread unread message${unread == 1 ? '' : 's'}'
            : 'Message',
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.forum_outlined),
            if (unread > 0)
              Positioned(
                top: -4,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ],
        ),
        onPressed: () =>
            context.push('/messages/$subjectId/${guardian.id}'),
      ),
    );
  }
}
