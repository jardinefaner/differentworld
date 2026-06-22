import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/activity_runtime/photography_runner_screen.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/photo-turns?block=<id>&prompt=<text>` — the host surface for
/// TIMED PER-CHILD photo turns (docs/PHOTO_TURNS).
///
/// The workflow, in the user's words: one phone, choose a child, give them
/// five minutes locked, they go shoot, "time's up — give to teacher", exit +
/// choose the next child; after everyone, a group review where each picks
/// favorites that file into per-child folders.
///
/// This screen is the SPINE — the "Whose turn?" roster picker. It does NOT
/// hold the camera; it launches [PhotographyRunnerScreen] in its timed-turn
/// mode for each child, tracks who's done in a local `Set`, and offers the
/// review once anyone has shot. The runner does the locked camera + countdown
/// + per-shot `captured_by_subject_id` stamping; this screen orchestrates the
/// turn-taking around it.
///
/// Roster source: when a block id is passed, the block's GROUP roster
/// (`subjectsInGroupProvider`); otherwise every child the viewer can see
/// (`subjectsInSpaceProvider`). Staff-run, so it's a normal (un-locked)
/// screen — the lock lives inside each child's turn.
class PhotoTurnsScreen extends ConsumerStatefulWidget {
  const PhotoTurnsScreen({
    this.blockId,
    this.prompt = 'Capture what you see',
    this.turnMinutes = 5,
    super.key,
  });

  /// The schedule block this run belongs to. When set, the roster is the
  /// block's group and every shot is tagged with this block id. Null ⇒ an
  /// ad-hoc run over the whole visible roster, no block tag.
  final String? blockId;

  /// The mission shown inside each child's locked turn.
  final String prompt;

  /// How many minutes each child gets on their locked turn — the countdown the
  /// runner shows. Comes from the session's shooting figure (via the route's
  /// `?minutes=`); defaults to 5. Clamped 1..20 at the call site so a stray
  /// value can't hand a child a 0- or 90-minute turn.
  final int turnMinutes;

  @override
  ConsumerState<PhotoTurnsScreen> createState() => _PhotoTurnsScreenState();
}

class _PhotoTurnsScreenState extends ConsumerState<PhotoTurnsScreen> {
  /// Children who've had their turn this session. Local, in-memory — a fresh
  /// run starts everyone "to go". (Durable "who shot today" lives in the
  /// attachments via `captured_by_subject_id`; this set is just the picker's
  /// progress UI.)
  final Set<String> _done = <String>{};

  /// Guards against a double-launch if the roster rebuilds mid-tap.
  bool _launching = false;

  Future<void> _startTurn(Subject child) async {
    // Set the guard SYNCHRONOUSLY (and via setState so the row grays at once):
    // `_RosterRow.onTap` fires `unawaited(_startTurn)`, so a double-tap lands
    // two synchronous calls in the same frame — without setting the flag before
    // the first `await`, both race past the check and launch two runners.
    if (_launching) return;
    setState(() => _launching = true);
    final fullName = '${child.firstName} ${child.lastName}'.trim();
    final firstName = child.firstName.trim();
    // Capture the navigator now so the callback doesn't reach for a stale
    // context after the runner's tree is gone.
    final navigator = Navigator.of(context);
    try {
      // Push the runner as this child's timed turn. `onTurnEnded` is how the
      // runner hands control back when staff reclaim the phone (after the
      // buzzer or an early corner-unlock): pop the runner; the child is marked
      // done on return below.
      await navigator.push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PhotographyRunnerScreen(
            prompt: widget.prompt,
            turnSubjectId: child.id,
            turnSubjectName: firstName.isEmpty ? fullName : firstName,
            // The countdown each child sees — the session's shooting minutes,
            // clamped 1..20 at the route. `turnDuration` seeds `_secondsLeft`
            // in the runner, which drives the one-second periodic countdown.
            turnDuration: Duration(minutes: widget.turnMinutes.clamp(1, 20)),
            scheduleBlockId: widget.blockId,
            onTurnEnded: () {
              // Guard on `mounted` (the picker could have been disposed while
              // the runner was up) AND `canPop` (a fast double-fire) so the pop
              // never touches a stale navigator.
              if (mounted && navigator.canPop()) navigator.pop();
            },
          ),
        ),
      );
    } finally {
      // Always clear the guard — even if the route builder throws — so the
      // picker can never deadlock with the button stuck.
      if (mounted) {
        // Back here once the runner route is gone — whether via onTurnEnded,
        // the buzzer→corner unlock→pop, or a staff back-out. Mark the child
        // done so the roster moves on. (Marking on return — not inside the
        // callback — means an early back-out still counts as "their turn
        // happened".)
        setState(() {
          _done.add(child.id);
          _launching = false;
        });
      } else {
        _launching = false;
      }
    }
  }

  void _openReview() {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PhotoTurnsReviewScreen(blockId: widget.blockId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Roster: block's group when launched from a block, else the visible
    // space roster.
    final blockId = widget.blockId;
    final AsyncValue<List<Subject>> rosterAsync;
    if (blockId != null) {
      final block = ref.watch(scheduleBlockByIdProvider(blockId));
      rosterAsync = block.when(
        data: (b) => b == null
            ? const AsyncValue<List<Subject>>.data(<Subject>[])
            : ref.watch(subjectsInGroupProvider(b.groupId)),
        loading: () => const AsyncValue<List<Subject>>.loading(),
        error: AsyncValue<List<Subject>>.error,
      );
    } else {
      rosterAsync = ref.watch(subjectsInSpaceProvider);
    }

    // Re-hydrate progress from the data layer so a process-kill mid-session
    // doesn't show everyone "to go": when launched from a block, every shot
    // already carries `schedule_block_id`, so one stream gives the set of
    // children who've shot. Merge it with the in-memory `_done`. (No cheap
    // single-query equivalent for the ad-hoc no-block case, so that path
    // relies on `_done` alone.)
    final effectiveDone = <String>{..._done};
    if (blockId != null) {
      final blockShots = ref.watch(attachmentsForBlockProvider(blockId)).value;
      if (blockShots != null) {
        for (final a in blockShots) {
          final by = a.capturedBySubjectId;
          if (by != null) effectiveDone.add(by);
        }
      }
    }

    return EdgeScaffold(
      body: SafeArea(
        bottom: false,
        child: rosterAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            title: "Couldn't load the roster",
            detail: 'Check your connection and try again.',
            onRetry: () {
              if (blockId != null) {
                ref.invalidate(scheduleBlockByIdProvider(blockId));
              } else {
                ref.invalidate(subjectsInSpaceProvider);
              }
            },
          ),
          data: (roster) => _content(context, roster, effectiveDone),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    List<Subject> roster,
    Set<String> done,
  ) {
    final theme = Theme.of(context);
    if (roster.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.photo_camera_outlined,
          title: 'No children to photograph',
          message:
              'Add children to this group first, then everyone gets a turn '
              'with the camera.',
        ),
      );
    }

    final remaining = roster.where((c) => !done.contains(c.id)).length;
    final anyDone = done.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        ContentHeader(
          title: 'Whose turn?',
          subtitle: remaining == 0
              ? 'Everyone has had a turn. Open the review to pick favorites.'
              : 'Tap a child to start their five minutes. '
                    '$remaining still to go.',
        ),
        for (final child in roster)
          _RosterRow(
            child: child,
            done: done.contains(child.id),
            onTap: () => unawaited(_startTurn(child)),
          ),
        const SizedBox(height: 16),
        // Review — available the moment anyone has shot, so staff can pick
        // favorites together at the end (or check in mid-way).
        FilledButton.icon(
          onPressed: anyDone ? _openReview : null,
          icon: const Icon(Icons.favorite_outline),
          label: const Text('Review & pick favorites'),
        ),
        if (!anyDone)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'The review opens once the first child has taken their turn.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// One child in the "Whose turn?" roster. Done children read as done (a check
/// + dimmed), but stay tappable for a re-do (a kid who needs another go).
class _RosterRow extends StatelessWidget {
  const _RosterRow({
    required this.child,
    required this.done,
    required this.onTap,
  });

  final Subject child;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = '${child.firstName} ${child.lastName}'.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: done ? 0.6 : 1,
        child: FeatureCard(
          onTap: onTap,
          leading: PersonAvatar(
            name: fullName.isEmpty ? child.firstName : fullName,
            photoUrl: child.photoUrl,
          ),
          title: fullName.isEmpty ? child.firstName : fullName,
          subtitle: done ? 'Had their turn — tap to redo' : 'Tap to start',
          trailing: done
              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
              : const Icon(Icons.camera_alt_outlined),
        ),
      ),
    );
  }
}

/// `PhotoTurnsReviewScreen` — the warm "Pick your favorites" review after the
/// turns (docs/PHOTO_TURNS). One strip per child who shot, with a heart on
/// each photo. A hearted photo files to the TOP of that child's folder.
///
/// FAVORITE STORAGE — no extra migration: the heart reuses `sort_order` as a
/// favorite flag. Hearted ⇒ `sort_order = 0`; un-hearted ⇒ a high sentinel
/// (1e9). The per-child folder reads via [attachmentsCapturedByCuratedProvider]
/// which orders `COALESCE(sort_order, 1e9) ASC, created_at DESC`, so favorites
/// float to the top of each child's progress folder. This is the documented
/// trade-off vs adding a boolean column: `sort_order` already exists and is
/// already synced, and the only loss is that we can't ALSO hand-order
/// non-favorites within a turn (acceptable — turns don't need manual ordering).
class PhotoTurnsReviewScreen extends ConsumerWidget {
  const PhotoTurnsReviewScreen({this.blockId, super.key});

  final String? blockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The roster to review = the block's group (if launched from one) else the
    // visible space roster. We only render a strip for children who actually
    // shot (their captured-by folder is non-empty), so an untouched roster
    // member doesn't clutter the review.
    final AsyncValue<List<Subject>> rosterAsync;
    final bid = blockId;
    if (bid != null) {
      final block = ref.watch(scheduleBlockByIdProvider(bid));
      rosterAsync = block.when(
        data: (b) => b == null
            ? const AsyncValue<List<Subject>>.data(<Subject>[])
            : ref.watch(subjectsInGroupProvider(b.groupId)),
        loading: () => const AsyncValue<List<Subject>>.loading(),
        error: AsyncValue<List<Subject>>.error,
      );
    } else {
      rosterAsync = ref.watch(subjectsInSpaceProvider);
    }

    return EdgeScaffold(
      body: SafeArea(
        bottom: false,
        child: rosterAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            title: "Couldn't load the review",
            detail: '$e',
          ),
          data: (roster) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              const ContentHeader(
                title: 'Pick your favorites',
                subtitle:
                    'Tap the heart on the best shots. Favorites file into '
                    'each child’s folder.',
              ),
              for (final child in roster)
                _ChildReviewStrip(
                  subjectId: child.id,
                  name: '${child.firstName} ${child.lastName}'.trim().isEmpty
                      ? child.firstName
                      : '${child.firstName} ${child.lastName}'.trim(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One child's review strip — their name + a horizontal row of the photos
/// they shot, each with a favorite heart. Hides itself entirely when the
/// child shot nothing (keeps the review to "who actually participated").
class _ChildReviewStrip extends ConsumerWidget {
  const _ChildReviewStrip({required this.subjectId, required this.name});

  final String subjectId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final photos =
        ref.watch(attachmentsCapturedByCuratedProvider(subjectId)).value ??
        const <Attachment>[];
    if (photos.isEmpty) return const SizedBox.shrink();

    final favorites = photos.where((p) => (p.sortOrder ?? 1) == 0).length;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  favorites == 0
                      ? '${photos.length} photos'
                      : '$favorites ♥ · ${photos.length} photos',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _ReviewPhoto(
                photo: photos[i],
                allUrls: photos.map((p) => p.url).toList(growable: false),
                index: i,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single photo in a child's review strip. Tap the image to view full; tap
/// the heart to favorite (writes `sort_order = 0`) or un-favorite (a high
/// sentinel). Optimistic + offline-safe (a typed Drift write through
/// `attachmentActions.reorder`, which PowerSync queues).
///
/// Stateful for ONE reason: a `_pending` guard. The heart's write is async and
/// the favorited state derives from the live `sort_order`, so a fast double-tap
/// could fire two writes before the stream re-emits — landing `0` then the
/// sentinel in an unpredictable order. `_pending` drops the second tap until
/// the first write returns.
class _ReviewPhoto extends ConsumerStatefulWidget {
  const _ReviewPhoto({
    required this.photo,
    required this.allUrls,
    required this.index,
  });

  final Attachment photo;
  final List<String> allUrls;
  final int index;

  @override
  ConsumerState<_ReviewPhoto> createState() => _ReviewPhotoState();
}

class _ReviewPhotoState extends ConsumerState<_ReviewPhoto> {
  /// Sentinel for "not a favorite" — see [PhotoTurnsReviewScreen]. Large so
  /// favorites (0) always sort above it.
  static const int _notFavorite = 1000000000;

  /// A favorite write is in flight — drop further taps until it returns.
  bool _pending = false;

  bool get _favorited => (widget.photo.sortOrder ?? 1) == 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fav = _favorited;
    return SizedBox(
      width: 118,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _openViewer,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _PhotoThumb(urlOrPath: widget.photo.url),
              ),
            ),
          ),
          if (fav)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 4,
            bottom: 4,
            child: _FavoriteButton(
              favorited: fav,
              onTap: () => unawaited(_toggleFavorite()),
            ),
          ),
        ],
      ),
    );
  }

  void _openViewer() {
    // Reuse the shared full-screen viewer so the review's full-view matches
    // every other gallery (signed URLs, swipe, pinch).
    unawaited(
      PhotoViewer.open(
        context,
        urls: widget.allUrls,
        initialIndex: widget.index,
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    if (_pending) return;
    setState(() => _pending = true);
    final next = _favorited ? _notFavorite : 0;
    try {
      await ref
          .read(attachmentActionsProvider)
          .reorder(id: widget.photo.id, sortOrder: next);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }
}

/// A network/path thumbnail for a stored attachment, with calm placeholder +
/// broken-image fallbacks. Wraps the shared [PersonPhotoNetwork] so review
/// thumbnails sign + cache the same way every other photo does.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.urlOrPath});

  final String urlOrPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PersonPhotoNetwork(
      urlOrPath: urlOrPath,
      width: 118,
      height: 132,
      placeholderBuilder: (_) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorBuilder: (_) => ColoredBox(
        color: theme.colorScheme.surfaceContainerHigh,
        child: const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

/// The heart toggle on a review photo. Icon + fill (never colour alone), 48dp
/// tap target via the surrounding padding.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.favorited, required this.onTap});

  final bool favorited;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: favorited ? 'Remove favorite' : 'Mark favorite',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: Icon(
            favorited ? Icons.favorite : Icons.favorite_border,
            color: favorited ? Colors.pinkAccent : Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
