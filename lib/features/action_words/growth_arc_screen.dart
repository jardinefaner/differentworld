import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/growth_arc.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/growth/:subjectId` — a child's **growth arc**, cast on the shared present
/// spine (the fourth sibling of `/play-today`, `/arc`, `/journey`). Auto-
/// compiled from their collected Action Words into a story reel: the words
/// they lived most, the worlds they became, their emerging title. Cast it to
/// the room at the closing ceremony, or to a family at pickup.
class GrowthArcScreen extends ConsumerWidget {
  const GrowthArcScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = ref.watch(subjectByIdProvider(subjectId)).value;
    final collectionAsync = ref.watch(actionWordsCollectionProvider(subjectId));
    final collection = collectionAsync.value;

    if (collection == null) {
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
      ),
      accent: const Color(0xFF7C4DFF),
      emoji: '✨',
    );
  }
}
