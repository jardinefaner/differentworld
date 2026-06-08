import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/journey` — **one cast that walks the whole experience.** The summer's arc,
/// world by world, on the shared present surface (the third sibling of
/// `/play-today` and `/arc`): an orientation tour for staff or families, or a
/// season-opener for the room. Built from the live curriculum so it always
/// matches the program.
class JourneyTourScreen extends ConsumerWidget {
  const JourneyTourScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final worlds =
        ref.watch(curriculumWorldsProvider).value ?? const <CurriculumWorld>[];
    if (worlds.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The journey is loading…',
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
      beats: buildJourneyTour(worlds),
      accent: const Color(0xFF7C4DFF),
      emoji: '✨',
    );
  }
}
