import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/guardians/guardians_providers.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
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

  /// We only auto-jump to the bottom on the FIRST frame the messages
  /// list resolves with data — after that, the user might be scrolling
  /// back through history and we mustn't yank them away.
  bool _didInitialScroll = false;

  /// User toggles the privacy preamble open / closed. It's important
  /// (legal/PII reminder) but it takes a chunk of the viewport — let
  /// the user collapse it after reading.
  bool _showPreamble = true;

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

  void _scheduleInitialScrollToBottom() {
    if (_didInitialScroll) return;
    _didInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
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
    // Wave 113: dynamic tab title — the child's first name in the
    // active thread. "Messages · Emma" on the family side reads as
    // a real chat-app title.
    final subject = ref.watch(subjectByIdProvider(widget.subjectId)).value;
    final threadTitle = subject == null
        ? 'Messages'
        : 'Messages · ${subject.firstName}';

    return RouteTitle(
      title: threadTitle,
      child: EdgeScaffold(
      body: Column(
        children: [
          // Shell now reserves the top chrome height; no per-screen
          // SizedBox needed.
          // Privacy preamble — collapsible to a single tap-to-expand
          // pill once the user has acknowledged it.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _showPreamble
                ? Stack(
                    children: [
                      const ContentHeader(
                        title: 'Messages',
                        subtitle:
                            'A direct line between family and staff for '
                            "this child. Don't share medical specifics "
                            "or anything you wouldn't put in writing.",
                        bottomGap: 8,
                      ),
                      Positioned(
                        top: 8,
                        right: 0,
                        child: IconButton(
                          tooltip: 'Hide reminder',
                          icon: const Icon(
                            Icons.keyboard_arrow_up,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _showPreamble = false),
                        ),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(
                      children: [
                        Text('Messages', style: theme.textTheme.titleLarge),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Show reminder',
                          icon: const Icon(Icons.info_outline, size: 20),
                          onPressed: () =>
                              setState(() => _showPreamble = true),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingSlot(),
              error: (_, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load this thread.'),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => ref.invalidate(
                          messageThreadProvider(threadKey),
                        ),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
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
                // First frame after data lands: jump to the bottom so
                // the user sees the latest message immediately.
                _scheduleInitialScrollToBottom();
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
    final mine =
        (message.senderKind == MessageSenderKind.guardian) == iAmGuardian;

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
            // Wave 107: cap absolute bubble width at 560dp so a
            // one-sentence message doesn't render as a 1400dp
            // ribbon on a desktop browser. The 75% floor still
            // applies on narrow phones (75% of 360 = 270dp).
            constraints: BoxConstraints(
              maxWidth: math.min(
                560,
                MediaQuery.sizeOf(context).width * 0.75,
              ),
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
                      if (mine) ...[
                        const SizedBox(width: 6),
                        _ReadReceipt(
                          message: message,
                          // Per-guardian read-state only matters for
                          // staff looking at their own outgoing
                          // messages — that's when "Seen by Mom only"
                          // vs "Seen by both" is the useful signal.
                          // Guardians looking at their own outgoing
                          // messages just see the staff-side first-
                          // read timestamp.
                          showPerGuardianBreakdown: !iAmGuardian,
                          textColor: fg,
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

/// Read-state badge on the sender's own bubble.
///
/// Two code paths:
///
/// * **Guardian-side (showPerGuardianBreakdown=false)** — falls back
///   to the legacy `read_at` semantics. Two glyphs: single check
///   (sent, not yet read) or double check + "Seen" (staff opened
///   the thread). This is all a parent needs to know.
///
/// * **Staff-side (showPerGuardianBreakdown=true)** — Devon persona.
///   On a single-guardian thread, falls back to the legacy
///   `read_at` semantics. On a multi-guardian thread (divorced
///   parents share a kid), parses `read_by_guardian_ids` and
///   compares against the guardians attached to the subject, so
///   the bubble reads "Seen by Mom" / "Seen by Mom & Dad" /
///   "Seen by 2 of 3" instead of a misleading "Seen" the moment
///   one parent opens it.
class _ReadReceipt extends ConsumerWidget {
  const _ReadReceipt({
    required this.message,
    required this.showPerGuardianBreakdown,
    required this.textColor,
  });

  final Message message;
  final bool showPerGuardianBreakdown;
  final Color textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final softFg = textColor.withValues(alpha: 0.7);
    final dimFg = textColor.withValues(alpha: 0.5);

    Widget sentOnly() => Icon(Icons.done, size: 14, color: dimFg);

    Widget seenLabel(String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.done_all, size: 14, color: softFg),
        const SizedBox(width: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: softFg,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    // Guardian-side reading is single-recipient (the staff) — no
    // breakdown to show. Same fallback when the per-guardian list
    // is empty (older messages from before the migration).
    if (!showPerGuardianBreakdown) {
      return message.readAt != null ? seenLabel('Seen') : sentOnly();
    }

    final guardiansAsync = ref.watch(
      guardiansForSubjectProvider(message.subjectId),
    );
    final guardians = guardiansAsync.value;
    if (guardians == null) {
      // Still loading the guardian list. Fall back to the legacy
      // single-bit indicator rather than blocking the bubble paint.
      return message.readAt != null ? seenLabel('Seen') : sentOnly();
    }

    final readIds = _parseReadByIds(message.readByGuardianIds ?? '');
    final readGuardians = guardians
        .where((g) => readIds.contains(g.id))
        .toList(growable: false);
    final total = guardians.length;
    final readCount = readGuardians.length;

    if (readCount == 0) {
      // Legacy `read_at` may still be set by older messages; respect
      // it so we don't regress to "Sent" on a row that used to say
      // "Seen" before the schema bump.
      return message.readAt != null ? seenLabel('Seen') : sentOnly();
    }

    if (total <= 1) {
      // Single-guardian thread — "Seen by Mom" is overkill; the
      // simple "Seen" reads cleaner.
      return seenLabel('Seen');
    }

    if (readCount >= total) {
      return seenLabel('Seen by all');
    }

    // Multi-guardian thread with partial reads. Use names if we
    // can fit two; otherwise a count.
    if (readCount == 1) {
      final name = _shortName(readGuardians.single.name);
      return seenLabel('Seen by $name');
    }
    if (readCount == 2) {
      final a = _shortName(readGuardians[0].name);
      final b = _shortName(readGuardians[1].name);
      return seenLabel('Seen by $a & $b');
    }
    return seenLabel('Seen by $readCount of $total');
  }

  /// `read_by_guardian_ids` is stored as a JSON-encoded string. Empty
  /// or malformed values are treated as no-one-has-read-yet — never
  /// throw from a bubble paint.
  static Set<String> _parseReadByIds(String raw) {
    if (raw.isEmpty) return const <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } on FormatException {
      // Corrupt cell — pretend it's empty.
    }
    return const <String>{};
  }

  /// First word of a guardian name keeps the bubble narrow: "Sarah J"
  /// → "Sarah". Falls back to "Parent" if the field is empty.
  static String _shortName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Parent';
    final firstSpace = trimmed.indexOf(' ');
    if (firstSpace <= 0) return trimmed;
    return trimmed.substring(0, firstSpace);
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
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach affordance — stubbed until photo capture is
            // wired through the same Supabase Storage path the rest
            // of the app uses. The button is visible so users learn
            // the path exists; the actual upload comes next.
            IconButton(
              tooltip: 'Attach a photo',
              icon: const Icon(Icons.add_photo_alternate_outlined),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Photo attachments are coming soon — for now '
                      'send the photo via email or text.',
                    ),
                  ),
                );
              },
            ),
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
            const SizedBox(width: 6),
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
