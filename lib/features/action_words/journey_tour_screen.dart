import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
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
      // EdgeScaffold — NOT a raw black Scaffold — so this transient loading
      // state clears the floating chrome instead of rendering under it; the
      // chrome's own back/hamburger is the way out. BeatPresenter owns
      // immersive on the happy path below.
      return const EdgeScaffold(
        body: LoadingSlot(variant: LoadingVariant.spinner),
      );
    }
    return BeatPresenter(
      beats: buildJourneyTour(worlds),
      accent: const Color(0xFF7C4DFF),
      emoji: '✨',
    );
  }
}
