import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/captures/widgets/capture_sheet.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/captures` — the upward loop's input inbox. Open thoughts the team
/// has captured but not yet decided what to do with. Each row offers
/// the triage options (promote to observation / dismiss); the floating
/// action button opens the capture sheet so you can drop a new one in
/// from this screen without bouncing back to Today.
class CaptureInboxScreen extends ConsumerWidget {
  const CaptureInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capturesAsync = ref.watch(openCapturesProvider);
    return EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCaptureSheet(context),
        icon: const Icon(Icons.bolt_outlined),
        label: const Text('Capture'),
      ),
      body: capturesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load captures',
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Inbox is empty',
              message:
                  'Nothing waiting to triage. Tap Capture to drop in a '
                  'quick "I noticed…" — you can decide what to do with '
                  'it later.',
              action: FilledButton.icon(
                onPressed: () => showCaptureSheet(context),
                icon: const Icon(Icons.bolt_outlined),
                label: const Text('Capture'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: 'Capture inbox',
                  subtitle:
                      'What you noticed. Promote it to an observation, '
                      'or dismiss it.',
                ),
              ),
              for (final c in rows)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: _CaptureCard(capture: c),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// One row in the inbox. Tap → action sheet (promote / dismiss).
class _CaptureCard extends ConsumerWidget {
  const _CaptureCard({required this.capture});

  final Capture capture;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final created = DateTime.tryParse(capture.createdAt)?.toLocal();
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openTriage(context, ref, capture),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: Icon(
                  Icons.bolt_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capture.body,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeTime(created),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Triage',
                icon: const Icon(Icons.more_vert),
                onPressed: () => _openTriage(context, ref, capture),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openTriage(
  BuildContext context,
  WidgetRef ref,
  Capture capture,
) async {
  unawaited(HapticFeedback.selectionClick());
  // Snapshot the stable dependencies BEFORE opening the sheet — the
  // sheet's own BuildContext/WidgetRef die the moment it pops, so any
  // post-pop work (the subject picker, the snackbar, the discard
  // mutation) has to use these captured references instead.
  final actions = ref.read(captureActionsProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  // The card's context survives sheet dismissal; use it for any
  // follow-up navigators (e.g. opening the subject picker).
  final parentContext = context;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => _TriageSheet(
      capture: capture,
      onDismiss: () async {
        Navigator.of(sheetCtx).pop();
        try {
          await actions.discard(capture.id);
        } on Exception catch (e, st) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: e,
              stack: st,
              library: 'captures',
            ),
          );
        }
      },
      onMakeObservation: () async {
        Navigator.of(sheetCtx).pop();
        await _pickSubjectAndPromote(
          rootContext: parentContext,
          actions: actions,
          messenger: messenger,
          capture: capture,
        );
      },
    ),
  );
}

typedef _AsyncAction = Future<void> Function();

class _TriageSheet extends StatelessWidget {
  const _TriageSheet({
    required this.capture,
    required this.onDismiss,
    required this.onMakeObservation,
  });

  final Capture capture;
  final _AsyncAction onDismiss;
  final _AsyncAction onMakeObservation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              capture.body,
              style: theme.textTheme.bodyLarge,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Make this an observation'),
              subtitle: const Text('Pick a child to attach it to'),
              onTap: () => unawaited(onMakeObservation()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: const Text('Dismiss'),
              subtitle: const Text(
                'Not going to act on this. Hide from inbox.',
              ),
              onTap: () => unawaited(onDismiss()),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pickSubjectAndPromote({
  required BuildContext rootContext,
  required CaptureActions actions,
  required ScaffoldMessengerState? messenger,
  required Capture capture,
}) async {
  final picked = await showModalBottomSheet<Subject>(
    context: rootContext,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _SubjectPickerSheet(),
  );
  if (picked == null) return;
  try {
    await actions.promoteToObservation(
      captureId: capture.id,
      subjectId: picked.id,
    );
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Saved as an observation for ${picked.firstName}.'),
      ),
    );
  } on Exception catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: 'captures'),
    );
    messenger?.showSnackBar(
      const SnackBar(content: Text('Could not promote the capture.')),
    );
  }
}

class _SubjectPickerSheet extends ConsumerStatefulWidget {
  const _SubjectPickerSheet();

  @override
  ConsumerState<_SubjectPickerSheet> createState() =>
      _SubjectPickerSheetState();
}

class _SubjectPickerSheetState
    extends ConsumerState<_SubjectPickerSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    final filtered = _filter.trim().isEmpty
        ? subjects
        : subjects.where((s) {
            final q = _filter.toLowerCase();
            return s.firstName.toLowerCase().contains(q) ||
                s.lastName.toLowerCase().contains(q);
          }).toList();
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.face_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Whose observation is this?',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search children',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          subjects.isEmpty
                              ? 'No children in your program yet.'
                              : 'No match.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          final fullName = [
                            s.firstName,
                            if (s.lastName.isNotEmpty) s.lastName,
                          ].join(' ');
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: s.photoUrl == null
                                  ? null
                                  : NetworkImage(s.photoUrl!),
                              child: s.photoUrl == null
                                  ? Text(
                                      s.firstName.isEmpty
                                          ? '?'
                                          : s.firstName[0].toUpperCase(),
                                    )
                                  : null,
                            ),
                            title: Text(fullName),
                            onTap: () => Navigator.of(context).pop(s),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _relativeTime(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${(diff.inDays / 7).floor()} wk ago';
}
