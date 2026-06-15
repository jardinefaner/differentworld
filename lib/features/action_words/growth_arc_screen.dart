import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/growth_arc.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The child's photos for the growth arc — newest-first, from their
/// observation attachments. Captions are SAFE by construction: the date,
/// never the observation body. The body is staff free-text that can name
/// OTHER children, and the arc is family-facing — so a body caption would
/// leak another kid's identity into this child's keepsake (the scrub rule,
/// CLAUDE.md). Date captions sidestep that entirely; richer scrubbed captions
/// are a follow-up. Capped at 6 so the reel stays a highlight, not a dump.
// ignore: specify_nonobvious_property_types
final growthArcPhotosProvider =
    FutureProvider.autoDispose.family<List<GrowthPhoto>, String>(
  (ref, subjectId) async {
    // ref.read (not watch): the arc is a one-time snapshot built when the
    // screen opens — a live subscription per attachment would re-subscribe N
    // providers on every rebuild and thrash the reel mid-cast on sync events.
    final entries = await ref.read(
      entriesForSubjectProvider(
        (subjectId: subjectId, kind: EntryKind.observation),
      ).future,
    );
    final photos = <GrowthPhoto>[];
    for (final e in entries) {
      if (photos.length >= 6) break;
      final atts = await ref.read(
        attachmentsForEntityProvider((kind: 'entry', id: e.id)).future,
      );
      if (atts.isEmpty) continue;
      final ts = DateTime.tryParse(e.recordedAt)?.toLocal();
      photos.add((
        url: atts.first.url,
        caption: ts == null ? 'A moment' : DateFormat.MMMMd().format(ts),
      ));
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
    final collection = ref.watch(actionWordsCollectionProvider(subjectId)).value;
    final photosAsync = ref.watch(growthArcPhotosProvider(subjectId));

    // Wait for BOTH the collection and the photos before building, so the beat
    // list is stable — otherwise late-arriving photos would rebuild the run
    // mid-present and reset the page. Photos failing (no network for the
    // signed URLs) resolves to empty, not a stall.
    if (collection == null || photosAsync.isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Gathering the story…',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
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
