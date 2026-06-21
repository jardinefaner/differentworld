import 'dart:async';

import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/present_deck_overview_setting.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/features/action_words/widgets/deck_overview.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The journey's deck accent — purple. Shared between the immersive presenter
/// and the deck overview so both read as the same surface.
const _journeyAccent = Color(0xFF7C4DFF);

/// `/journey` — **one cast that walks the whole experience.** The summer's arc,
/// world by world, on the shared present surface (the third sibling of
/// `/play-today` and `/arc`): an orientation tour for staff or families, or a
/// season-opener for the room. Built from the live curriculum so it always
/// matches the program.
///
/// With the **deck-overview** toggle on (`presentDeckOverviewProvider`, default
/// off), this renders a tappable grid of world beats instead of dropping
/// straight into the slideshow — tap any tile to present from THAT world. Off
/// (the default) keeps the exact immersive behaviour.
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

    final beats = buildJourneyTour(worlds);

    final overview = bentoEnabled(
      ref,
      perScreen: ref.watch(presentDeckOverviewProvider).value,
    );
    if (overview) {
      // The tappable grid. Each tile presents the deck from its beat; the
      // immersive presenter rides the nested `/journey/present` route. The
      // journey leaves onBeatChanged null (no resume — it's a walkthrough).
      return EdgeScaffold(
        body: DeckOverview(
          beats: beats,
          accent: _journeyAccent,
          emoji: '✨',
          title: 'The journey',
          subtitle: '${worlds.length} worlds · tap any to start there',
          onPresent: (i) => unawaited(
            context.push(
              '/journey/present',
              extra: DeckPresentArgs(
                beats: beats,
                accent: _journeyAccent,
                emoji: '✨',
                initialBeat: i,
              ),
            ),
          ),
        ),
      );
    }

    // Toggle OFF — the exact prior behaviour: straight into the immersive run.
    return BeatPresenter(
      beats: beats,
      accent: _journeyAccent,
      emoji: '✨',
    );
  }
}
