import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The states of the one clock-driven surface (docs/COCKPIT.md). The cockpit
/// renders exactly ONE at a time, chosen by [computeCockpitBeat]; everything
/// else recedes to the pull-down curiosity bar. Each beat is a FRAME over a
/// surface that already exists — the cockpit composes, it doesn't rebuild.
enum CockpitBeat {
  /// `prep` — peek at today's plan before the rush.
  gettingReady,

  /// `arrival` — greet, the journey number, mood, "pick today's verbs".
  goodMorning,

  /// `program` — the live block (or a gap): run / observe / attend. A world
  /// block IS "verb hour" (the lead already leads with "Run the session").
  now,

  /// A live field trip — bends the clock (see [computeCockpitBeat]); the
  /// vehicle checkout + trip roster + headcount.
  fieldTrip,

  /// The closing window — the dark, glowing reveal stage. NOT auto-selected in
  /// slice 1 (no generic end-of-day signal); reached by the beat rail.
  reveal,

  /// `pickup` — the release board.
  pickup,

  /// `closed`, kids were here today — the per-child parent message.
  send,

  /// `closed`, nothing to send — the day at rest.
  closed,
}

/// Pure core of the cockpit: the moment → the one beat. Expressed over
/// primitives (no Riverpod) so it's unit-testable, exactly like
/// [computeContextLead], the layer directly below it. [cockpitBeatProvider] is
/// the thin adapter that reads the live providers and calls this.
///
/// The off-schedule rule (docs/COCKPIT.md fork ③): a LIVE block wins over the
/// time of day — a field trip at 10 a.m. is the trip cockpit, not "program
/// time". [CockpitBeat.reveal] is deliberately NOT auto-selected: no fixed
/// end-of-day exists across programs/verticals, so slice 1 reaches it by hand
/// (the beat rail); its auto-trigger is a later slice.
CockpitBeat computeCockpitBeat({
  required DayPhase phase,
  String? liveBlockKind,
  bool sendable = false,
}) {
  if (liveBlockKind == BlockKind.fieldTrip) return CockpitBeat.fieldTrip;
  return switch (phase) {
    DayPhase.prep => CockpitBeat.gettingReady,
    DayPhase.arrival => CockpitBeat.goodMorning,
    DayPhase.program => CockpitBeat.now,
    DayPhase.pickup => CockpitBeat.pickup,
    DayPhase.closed => sendable ? CockpitBeat.send : CockpitBeat.closed,
  };
}

/// Reads the live providers and resolves the current beat. Honors the context
/// room override (the same pin the context pill sets) so a teacher who floats
/// rooms gets the right room's live block.
// Riverpod 3 auto-dispose providers have no stable public type name.
// ignore: specify_nonobvious_property_types
final cockpitBeatProvider = Provider.autoDispose<CockpitBeat>((ref) {
  final phase =
      ref.watch(dayPhaseProvider).value ?? DayPhase.fromClock(DateTime.now());
  final override = ref.watch(contextRoomOverrideProvider);
  final live = override == null
      ? ref.watch(liveBlockProvider)
      : ref.watch(liveBlockForGroupProvider(override));
  // Sendable = the day had kids, so `closed` becomes "send home" rather than
  // the rest state. Cheap read; refined per-child in a later slice.
  final subjects = ref.watch(subjectsInSpaceProvider).value;
  return computeCockpitBeat(
    phase: phase,
    liveBlockKind: live?.kind,
    sendable: subjects != null && subjects.isNotEmpty,
  );
});
