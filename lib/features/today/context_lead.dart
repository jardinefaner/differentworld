import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One immediately-useful move offered by the contextual lead. A tap
/// pushes [route]. Kept deliberately tiny — the whole point of the lead
/// is that a context surfaces only the 1–3 moves it actually calls for.
class ContextMove {
  const ContextMove({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

/// Colour family for the lead, chosen by the moment (not by content).
enum ContextTone {
  /// Active "go" — arrival, a running activity. Primary container.
  go,

  /// On a field trip. Tertiary (warm) container — matches the schedule
  /// agenda's field-trip accent so the two surfaces speak the same colour.
  trip,

  /// Pickup window. Secondary container.
  pickup,

  /// Quiet — prep, or program-time with nothing live. Neutral surface.
  calm,
}

/// The single "what matters right now" briefing the home screen leads with.
/// [primary] is the card's main tap; [more] are ≤2 secondary chips. The
/// north star (docs/VISION.md, "context is the navigation"): show ONLY the
/// immediate utility for this moment — never a wall of every tool.
class ContextLead {
  const ContextLead({
    required this.eyebrow,
    required this.title,
    required this.line,
    required this.icon,
    required this.tone,
    required this.primary,
    this.more = const <ContextMove>[],
  });

  final String eyebrow;
  final String title;
  final String line;
  final IconData icon;
  final ContextTone tone;
  final ContextMove primary;
  final List<ContextMove> more;
}

/// The minimal shape of the live block the lead needs — kept as a plain
/// record so [computeContextLead] is pure and testable without the
/// `LiveBlock` provider graph.
typedef LiveBlockInfo = ({
  String blockId,
  String groupId,
  String title,
  String kind,
});

/// Arrival headcount, as primitives, for the same reason.
typedef ArrivalInfo = ({int total, int inBuilding, int stillOut, bool allIn});

/// Pure core of the contextual lead — the "only immediate utility per
/// context" decision, expressed over primitives so it's unit-testable
/// without Riverpod. [contextLeadProvider] is the thin adapter that reads
/// the live providers and calls this.
///
/// The live block wins: when a block is happening now, the lead reflects
/// THAT block and surfaces only its moves — a field trip reveals the
/// vehicle + roster; an on-site activity reveals run/observe/attendance.
/// With no live block we fall back to the day phase's single best move
/// (check-in at arrival, the release board at pickup, the schedule when
/// program-time has a gap or no schedule was entered).
ContextLead? computeContextLead({
  required bool isLogger,
  required DayPhase phase,
  required String kidsLabel,
  LiveBlockInfo? live,
  String? worldName,
  ArrivalInfo? arrival,
}) {
  // Today's lead is a staff move-prompt; guardians get the family lens.
  if (!isLogger) return null;
  if (phase == DayPhase.closed) return null;

  // ── A block is live → the lead IS that block. ─────────────────────────
  if (live != null) {
    if (live.kind == BlockKind.fieldTrip) {
      return ContextLead(
        eyebrow: 'ON A TRIP',
        title: live.title,
        line: 'Check the vehicle out before you roll.',
        icon: Icons.directions_bus_outlined,
        tone: ContextTone.trip,
        primary: const ContextMove(
          icon: Icons.directions_bus_outlined,
          label: 'Check out vehicle',
          route: '/vehicles',
        ),
        more: [
          ContextMove(
            icon: Icons.fact_check_outlined,
            label: 'Trip roster',
            route: '/trips/${live.blockId}',
          ),
        ],
      );
    }
    // On-site activity. A running curriculum world → lead with the run;
    // otherwise the most useful bare move is to capture the moment.
    return ContextLead(
      eyebrow: 'RIGHT NOW',
      title: live.title,
      line: worldName != null
          ? 'In $worldName — full-screen, step by step.'
          : 'Log what the room is doing.',
      icon: Icons.play_circle_outline,
      tone: ContextTone.go,
      primary: worldName != null
          ? const ContextMove(
              icon: Icons.slideshow_outlined,
              label: 'Run the session',
              route: '/play-today',
            )
          : const ContextMove(
              icon: Icons.bolt_outlined,
              label: 'Capture a moment',
              route: '/captures/new',
            ),
      more: [
        ContextMove(
          icon: Icons.fact_check_outlined,
          label: 'Attendance',
          route: '/groups/${live.groupId}/attendance',
        ),
        if (worldName != null)
          const ContextMove(
            icon: Icons.bolt_outlined,
            label: 'Observe',
            route: '/captures/new',
          ),
      ],
    );
  }

  // ── No live block → the day phase's single best move. ─────────────────
  final kids = kidsLabel;
  switch (phase) {
    case DayPhase.arrival:
      final prog = arrival;
      final line = (prog != null && prog.total > 0)
          ? (prog.allIn
              ? 'All ${prog.total} checked in — nice work.'
              : '${prog.inBuilding} of ${prog.total} in · ${prog.stillOut} to go')
          : 'Check $kids in as they arrive.';
      return ContextLead(
        eyebrow: 'RIGHT NOW',
        title: 'Arrival',
        line: line,
        icon: Icons.login,
        tone: ContextTone.go,
        primary: const ContextMove(
          icon: Icons.login,
          label: 'Check in',
          route: '/checklist?filter=unmarked',
        ),
      );
    case DayPhase.pickup:
      return ContextLead(
        eyebrow: 'RIGHT NOW',
        title: 'Pickup',
        line: 'Release $kids to authorized pickup.',
        icon: Icons.directions_walk,
        tone: ContextTone.pickup,
        primary: const ContextMove(
          icon: Icons.directions_walk,
          label: 'Pickup board',
          route: '/pickup',
        ),
      );
    case DayPhase.prep:
      return const ContextLead(
        eyebrow: 'COMING UP',
        title: 'Getting ready',
        line: 'Peek at today’s plan before the rush.',
        icon: Icons.wb_twilight_outlined,
        tone: ContextTone.calm,
        primary: ContextMove(
          icon: Icons.event_note_outlined,
          label: 'Today’s schedule',
          route: '/schedule',
        ),
      );
    case DayPhase.program:
      // Program time, but nothing is live — a gap between blocks, or no
      // schedule was entered. Don't pretend; offer the always-useful move.
      return const ContextLead(
        eyebrow: 'RIGHT NOW',
        title: 'Program time',
        line: 'Nothing scheduled right now.',
        icon: Icons.bolt_outlined,
        tone: ContextTone.calm,
        primary: ContextMove(
          icon: Icons.bolt_outlined,
          label: 'Capture a moment',
          route: '/captures/new',
        ),
        more: [
          ContextMove(
            icon: Icons.event_note_outlined,
            label: 'Schedule',
            route: '/schedule',
          ),
        ],
      );
    case DayPhase.closed:
      return null;
  }
}

/// Reads the live providers and hands primitives to [computeContextLead].
/// Returns null when there's nothing to lead with (non-logger, or closed).
// Riverpod 3 auto-dispose providers have no stable public type name.
// ignore: specify_nonobvious_property_types
final contextLeadProvider = Provider.autoDispose<ContextLead?>((ref) {
  final viewer = ref.watch(viewerProvider);
  final phase =
      ref.watch(dayPhaseProvider).value ?? DayPhase.fromClock(DateTime.now());
  final live = ref.watch(liveBlockProvider);
  final world = ref.watch(currentWorldProvider);
  final labels = ref.watch(verticalLabelsProvider);
  // Headcount only matters (and only loads) during arrival.
  final prog =
      phase == DayPhase.arrival ? ref.watch(arrivalProgressProvider).value : null;
  return computeContextLead(
    isLogger: viewer.isDailyLogger,
    phase: phase,
    kidsLabel: labels.subjectPlural.toLowerCase(),
    live: live == null
        ? null
        : (
            blockId: live.blockId,
            groupId: live.groupId,
            title: live.title,
            kind: live.kind,
          ),
    worldName: world?.name,
    arrival: prog == null
        ? null
        : (
            total: prog.total,
            inBuilding: prog.inBuilding,
            stillOut: prog.stillOut,
            allIn: prog.allIn,
          ),
  );
});
