import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/entities/linkified_text.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/attachment_photo_thumb.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:differentworld/shared/widgets/subject_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/captures` — the upward loop's input inbox. Open thoughts the team
/// has captured but not yet decided what to do with. Each row offers
/// the triage options (promote to observation / dismiss); the floating
/// action button opens the capture sheet so you can drop a new one in
/// from this screen without bouncing back to Today.
///
/// Visual: each row carries a colored age bar on its left edge — warm
/// for today's captures (act now), neutral for older items (drift),
/// muted for stale ones (you've been avoiding this).
///
/// Bulk dismiss: long-press any row → checkbox mode appears. Tap rows
/// to select, then "Dismiss N" in the AppBar wipes them in one go
/// (with undo). For inboxes that have piled up over a vacation.
class CaptureInboxScreen extends ConsumerStatefulWidget {
  const CaptureInboxScreen({super.key});

  @override
  ConsumerState<CaptureInboxScreen> createState() => _CaptureInboxScreenState();
}

class _CaptureInboxScreenState extends ConsumerState<CaptureInboxScreen> {
  final Set<String> _selected = <String>{};

  bool get _selectMode => _selected.isNotEmpty;

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _dismissSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final actions = ref.read(captureActionsProvider);
    _clearSelection();
    for (final id in ids) {
      await runReported(
        library: 'captures',
        action: () => actions.discard(id),
      );
    }
    if (!mounted) return;
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Dismissed ${ids.length} captures.'),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capturesAsync = ref.watch(openCapturesProvider);
    // Part of the app-wide "Bento everywhere" sweep — global-only toggle, no
    // per-screen provider. On → responsive card GRID; off → a plain list.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      showBack: !_selectMode,
      actions: _selectMode
          ? [
              TextButton.icon(
                onPressed: _dismissSelected,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text('Dismiss ${_selected.length}'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
              SecondaryActionButton(
                tooltip: 'Cancel',
                icon: Icons.close,
                onPressed: _clearSelection,
              ),
            ]
          : [
              PrimaryActionButton(
                tooltip: 'Capture',
                icon: Icons.bolt_outlined,
                onPressed: () => context.push('/captures/new'),
              ),
              const SyncStatusIndicator(),
            ],
      body: capturesAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load captures',
          onRetry: () => ref.invalidate(openCapturesProvider),
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
                onPressed: () => context.push('/captures/new'),
                icon: const Icon(Icons.bolt_outlined),
                label: const Text('Capture'),
              ),
            );
          }
          // "Bento everywhere": when on, captures flow as a responsive
          // card grid (1 col on phone, 2-3 on tablet/desktop) via the
          // max-cross-axis-extent delegate; when off, the calm single-
          // column list. SAME _CaptureCard cell in both. `mainAxisExtent`
          // pins a stable card height so the IntrinsicHeight age-bar row
          // never overflows a fixed grid cell.
          Widget cell(int i) {
            final c = rows[i];
            return _CaptureCard(
              capture: c,
              selectMode: _selectMode,
              selected: _selected.contains(c.id),
              onLongPress: () => _toggle(c.id),
              onTapInSelectMode: () => _toggle(c.id),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Expanded(
                child: bento
                    ? GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              // Tall enough for the worst case: 12+12 padding +
                              // the body's 96dp cap (4 lines) + the time row.
                              mainAxisExtent: 148,
                            ),
                        itemCount: rows.length,
                        itemBuilder: (_, i) => cell(i),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: rows.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: cell(i),
                        ),
                      ),
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
  const _CaptureCard({
    required this.capture,
    this.selectMode = false,
    this.selected = false,
    this.onLongPress,
    this.onTapInSelectMode,
  });

  final Capture capture;
  final bool selectMode;
  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTapInSelectMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Show a thumbnail when this capture carries photos (the shared
    // AttachmentPhotoThumb). `.value` (not requireValue) so a
    // still-loading stream just renders no thumb — never an error.
    final photos =
        ref
            .watch(
              attachmentsForEntityProvider((kind: 'capture', id: capture.id)),
            )
            .value
            ?.urls ??
        const <String>[];
    final created = DateTime.tryParse(capture.createdAt)?.toLocal();
    final ageDays = created == null
        ? 0
        : DateTime.now().difference(created).inDays;
    // Age bar tone: warm for today, drifting to neutral over a week.
    final ageColor = ageDays == 0
        ? scheme.primary
        : ageDays < 3
        ? scheme.tertiary
        : ageDays < 7
        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
        : scheme.error.withValues(alpha: 0.65);

    return Material(
      color: selected
          ? scheme.primaryContainer
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: selectMode
            ? onTapInSelectMode
            : () => _openTriage(context, ref, capture),
        onLongPress: onLongPress,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vertical age bar — the at-a-glance temporal cue.
              Container(width: 4, color: ageColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 10),
                        child: selectMode
                            ? Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              )
                            : Icon(
                                Icons.bolt_outlined,
                                color: scheme.primary,
                              ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: 40,
                                maxHeight: 96,
                              ),
                              child: Text(
                                capture.body,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              relativeTimeAgo(created),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Photo thumb — at-a-glance "this capture has a
                      // picture." Tapping the card still opens triage;
                      // the thumb is a passive cue, not a separate tap
                      // target (keeps the row's one-tap-to-triage model).
                      if (photos.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: AttachmentPhotoThumb(
                            photos: photos,
                            badgeOffset: -3,
                            errorIconSize: 20,
                          ),
                        ),
                      ],
                      if (!selectMode)
                        IconButton(
                          tooltip: 'Triage',
                          icon: const Icon(Icons.more_vert),
                          onPressed: () => _openTriage(context, ref, capture),
                        ),
                    ],
                  ),
                ),
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
  final parentContext = context;
  await showGlassSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetCtx) => _TriageSheet(
      capture: capture,
      onDismiss: () async {
        Navigator.of(sheetCtx).pop();
        // Wave 100: pass messenger + onSuccess so dismiss matches the
        // promote-to-task / promote-to-observation paths. Previously
        // dismiss was silent — the row disappeared, but with no
        // confirmation, easy to miss in a busy inbox.
        await runReported(
          library: 'captures',
          messenger: messenger,
          onSuccess: 'Capture dismissed.',
          onError: 'Could not dismiss the capture.',
          action: () => actions.discard(capture.id),
        );
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
      onMakeTask: () async {
        Navigator.of(sheetCtx).pop();
        await runReported(
          library: 'captures',
          messenger: messenger,
          onSuccess: 'Saved as a task.',
          onError: 'Could not create the task.',
          action: () => actions.promoteToTask(captureId: capture.id),
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
    required this.onMakeTask,
  });

  final Capture capture;
  final _AsyncAction onDismiss;
  final _AsyncAction onMakeObservation;
  final _AsyncAction onMakeTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The captured text up top so the triage decision has the
            // full context visible (no scroll to refresh memory).
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: LinkifiedText(
                capture.body,
                style: theme.textTheme.bodyLarge,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            // Three large M3-tinted action cards. Bigger affordances
            // for weightier decisions; color tells you the destination.
            FeatureCard(
              borderRadius: 16,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              tone: FeatureCardTone.selected,
              leading: Icon(
                Icons.menu_book_outlined,
                color: scheme.onPrimaryContainer,
                size: 26,
              ),
              title: 'Make this an observation',
              subtitle: 'Pick a child to attach it to',
              trailing: Icon(
                Icons.chevron_right,
                color: scheme.onPrimaryContainer,
              ),
              onTap: () => unawaited(onMakeObservation()),
            ),
            const SizedBox(height: 8),
            FeatureCard(
              borderRadius: 16,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              tone: FeatureCardTone.success,
              leading: Icon(
                Icons.check_circle_outline,
                color: scheme.onTertiaryContainer,
                size: 26,
              ),
              title: 'Make this a task',
              subtitle: 'A to-do that lives in /tasks until done',
              trailing: Icon(
                Icons.chevron_right,
                color: scheme.onTertiaryContainer,
              ),
              onTap: () => unawaited(onMakeTask()),
            ),
            const SizedBox(height: 8),
            FeatureCard(
              borderRadius: 16,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              tone: FeatureCardTone.danger,
              leading: Icon(
                Icons.delete_outline,
                color: scheme.onErrorContainer,
                size: 26,
              ),
              title: 'Dismiss',
              subtitle: 'Not going to act on this. Hide from inbox.',
              trailing: Icon(
                Icons.chevron_right,
                color: scheme.onErrorContainer,
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
  final picked = await pickSubject(
    rootContext,
    title: 'Whose observation is this?',
  );
  if (picked == null) return;
  await runReported(
    library: 'captures',
    messenger: messenger,
    onSuccess: 'Saved as an observation for ${picked.firstName}.',
    onError: 'Could not promote the capture.',
    action: () => actions.promoteToObservation(
      captureId: capture.id,
      subjectId: picked.id,
    ),
  );
}
