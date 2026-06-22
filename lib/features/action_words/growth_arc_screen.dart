import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/growth_arc.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The child's photos for the growth arc — their actual moments woven into
/// the reel. Two sources, the child's OWN shots first:
///
/// 1. **Photos they SHOT** ([attachmentsCapturedByProvider]) — the camera
///    turns where they were the photographer. Prime growth-book material:
///    it's what THEY made, not just what happened to them. Favorites-first
///    isn't needed here (the arc is a curated highlight, not the folder), so
///    we take them newest-first as the DAO returns them.
/// 2. **Photos on their observations** ([attachmentsForEntityProvider]) —
///    backfill so a child who never held the camera still gets moments.
///
/// Captions are SAFE by construction: the date, never any free-text body.
/// A body is staff free-text that can name OTHER children, and the arc is
/// family-facing — a body caption would leak another kid's identity into this
/// child's keepsake (the scrub rule, CLAUDE.md). Date captions sidestep that
/// entirely. Capped at 6 so the reel stays a highlight, not a dump.
// ignore: specify_nonobvious_property_types
final growthArcPhotosProvider = FutureProvider.autoDispose
    .family<List<GrowthPhoto>, String>(
      (ref, subjectId) async {
        // ref.read (not watch): the arc is a one-time snapshot built when the
        // screen opens — a live subscription per attachment would re-subscribe N
        // providers on every rebuild and thrash the reel mid-cast on sync events.
        final photos = <GrowthPhoto>[];
        final seen = <String>{};

        String dateCaption(String? iso) {
          final ts = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
          return ts == null ? 'A moment' : DateFormat.MMMMd().format(ts);
        }

        // 1. The child's own shots — what they MADE — lead the reel.
        final shot = await ref.read(
          attachmentsCapturedByProvider(subjectId).future,
        );
        for (final a in shot) {
          if (photos.length >= 6) break;
          if (!seen.add(a.url)) continue;
          photos.add((
            url: a.url,
            caption: dateCaption(a.takenAt ?? a.createdAt),
          ));
        }

        // 2. Backfill from observation attachments until we hit the cap.
        if (photos.length < 6) {
          final entries = await ref.read(
            entriesForSubjectProvider(
              (subjectId: subjectId, kind: EntryKind.observation),
            ).future,
          );
          for (final e in entries) {
            if (photos.length >= 6) break;
            final atts = await ref.read(
              attachmentsForEntityProvider((kind: 'entry', id: e.id)).future,
            );
            if (atts.isEmpty) continue;
            final url = atts.first.url;
            if (!seen.add(url)) continue;
            photos.add((url: url, caption: dateCaption(e.recordedAt)));
          }
        }
        return photos;
      },
    );

/// `/growth/:subjectId` — a child's **growth arc**, cast on the shared present
/// spine (the fourth sibling of `/play-today`, `/arc`, `/journey`). Auto-
/// compiled from their collected Action Words AND their actual photos into a
/// story reel: the words they lived most, the worlds they became, the moments
/// they made, their emerging title. Cast it to the room at the closing
/// ceremony, or to a family at pickup.
class GrowthArcScreen extends ConsumerWidget {
  const GrowthArcScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    final collection = ref
        .watch(actionWordsCollectionProvider(subjectId))
        .value;
    final photosAsync = ref.watch(growthArcPhotosProvider(subjectId));

    // Wait for BOTH the collection and the photos before building, so the beat
    // list is stable — otherwise late-arriving photos would rebuild the run
    // mid-present and reset the page. Photos failing (no network for the
    // signed URLs) resolves to empty, not a stall.
    if (collection == null || photosAsync.isLoading) {
      // EdgeScaffold — NOT a raw black Scaffold — so this transient loading
      // state clears the floating chrome instead of rendering under it; the
      // chrome's own back/hamburger is the way out. BeatPresenter owns
      // immersive on the happy path below.
      return const EdgeScaffold(
        body: LoadingSlot(variant: LoadingVariant.spinner),
      );
    }

    return BeatPresenter(
      beats: buildGrowthArc(
        firstName: subject?.firstName ?? '',
        collection: collection,
        photos: photosAsync.value ?? const <GrowthPhoto>[],
      ),
      accent: const Color(0xFF7C4DFF),
      emoji: '✨',
    );
  }
}
