import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A staff↔guardian thread about one child. Same screen for both
/// sides; the viewer determines which side renders.
class MessageThreadScreen extends ConsumerStatefulWidget {
  const MessageThreadScreen({
    required this.subjectId,
    required this.guardianId,
    super.key,
  });

  final String subjectId;
  final String guardianId;

  @override
  ConsumerState<MessageThreadScreen> createState() =>
      _MessageThreadScreenState();
}

class _MessageThreadScreenState
    extends ConsumerState<MessageThreadScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Mark anything previously unread in this thread as read on open.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final actions = ref.read(messageActionsProvider);
      await runReported(
        library: 'messages',
        action: () => actions.markThreadRead(
          subjectId: widget.subjectId,
          guardianId: widget.guardianId,
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    final actions = ref.read(messageActionsProvider);
    final ok = await runReported(
      library: 'messages',
      action: () => actions.send(
        subjectId: widget.subjectId,
        guardianId: widget.guardianId,
        body: body,
      ),
    );
    if (!mounted) return;
    if (ok) {
      _ctrl.clear();
    }
    setState(() => _sending = false);
    // Scroll the freshly-sent message into view after the stream
    // delivers it (a short delay is enough for the rebuild).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      unawaited(_scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final iAmGuardian = viewer is GuardianViewer;

    final threadKey = (
      subjectId: widget.subjectId,
      guardianId: widget.guardianId,
    );
    final messagesAsync = ref.watch(messageThreadProvider(threadKey));

    return EdgeScaffold(
      body: Column(
        children: [
          const SizedBox(height: 56),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(
              title: 'Messages',
              subtitle:
                  'A direct line between family and staff for this '
                  "child. Don't share medical specifics or anything you "
                  "wouldn't put in writing.",
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingSlot(),
              error: (_, _) => const Center(
                child: Text('Could not load this thread.'),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        iAmGuardian
                            ? 'Nothing here yet. Say hi to the team.'
                            : 'No messages yet from this family.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: messages.length,
                  itemBuilder: (_, i) =>
                      _MessageBubble(message: messages[i]),
                );
              },
            ),
          ),
          _Composer(
            controller: _ctrl,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final iAmGuardian = viewer is GuardianViewer;
    final mine = (message.senderKind == 'guardian') == iAmGuardian;

    final bg = mine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final fg = mine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    final when = DateTime.tryParse(message.createdAt)?.toLocal();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft:
                      mine ? const Radius.circular(16) : Radius.zero,
                  bottomRight:
                      mine ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.body, style: TextStyle(color: fg)),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        relativeTimeAgo(when),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: fg.withValues(alpha: 0.7),
                        ),
                      ),
                      // Read receipt: only on messages YOU sent. The
                      // other side never sees their own "you read this"
                      // marker — useless noise on incoming bubbles.
                      if (mine && message.readAt != null) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.done_all,
                          size: 14,
                          color: fg.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'Seen',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: fg.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (mine) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.done,
                          size: 14,
                          color: fg.withValues(alpha: 0.5),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: sending ? null : () => unawaited(onSend()),
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}
