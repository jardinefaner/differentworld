import 'dart:async';

import 'package:differentworld/features/action_words/block_run.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The "use right now" tray for a run-of-show slide — the app features a host
/// would reach for while standing ON a block, so the slide is a *launchpad*, not
/// just a teleprompter (docs/VISION.md 2026-06-29 "the slide is a launchpad").
///
/// Two layers, so the per-kind mapping is pure + testable while the wiring stays
/// in the widget tree:
///   - [blockActionKindsFor] — pure (scheduleKind, title, hasSession) → the
///     ordered list of [BlockActionKind]s for that block. Unit-tested.
///   - [blockActionsFor] — binds those kinds to real launchers ([BeatAction]s),
///     reusing the SAME routes the per-block sheet (block_run_sheet) already
///     proves out, so the slide and the sheet stay one source of truth.
///
/// HOST-ONLY by the casting law: this rides the paper deck-overview card (which
/// is never mirrored), never the immersive `BeatPresenter` (which a TV can
/// mirror) — the room keeps seeing the clean slide.

/// A launchable feature on a slide — icon + short label + the tap that opens it.
@immutable
class BeatAction {
  const BeatAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// The features a block can launch. Pure enum so the per-kind mapping is
/// testable without a BuildContext.
enum BlockActionKind {
  checkIn,
  headcount,
  capture,
  observe,
  incident,
  message,
  pickup,
  wordsPick,
  runDeck,
  runActivity,
  cast,
  tripBoard,
  notify,
}

/// The ordered actions for a block, from its schedule kind + title (+ whether it
/// carries a curriculum session). Pure — the precedence reuses
/// [classifyRoutine] so a routine's tray matches how the day-run already reads
/// it. A photo/session block and a field trip are special; everything else maps
/// through its routine family, falling back to a generic do-it tray.
List<BlockActionKind> blockActionKindsFor({
  required String scheduleKind,
  required String title,
  required bool hasSession,
}) {
  if (hasSession) {
    return const [
      BlockActionKind.runDeck,
      BlockActionKind.cast,
      BlockActionKind.capture,
      BlockActionKind.observe,
    ];
  }
  if (scheduleKind == 'field_trip') {
    return const [
      BlockActionKind.tripBoard,
      BlockActionKind.notify,
      BlockActionKind.message,
    ];
  }
  switch (classifyRoutine(scheduleKind, title)) {
    case RoutineKind.arrival:
      return const [
        BlockActionKind.checkIn,
        BlockActionKind.capture,
        BlockActionKind.message,
      ];
    case RoutineKind.meal:
      return const [
        BlockActionKind.headcount,
        BlockActionKind.capture,
        BlockActionKind.observe,
      ];
    case RoutineKind.rest:
      return const [BlockActionKind.capture, BlockActionKind.observe];
    case RoutineKind.pickup:
      return const [
        BlockActionKind.pickup,
        BlockActionKind.message,
        BlockActionKind.capture,
      ];
    case RoutineKind.transition:
      return const [BlockActionKind.headcount, BlockActionKind.cast];
    case RoutineKind.welcome:
      return const [
        BlockActionKind.wordsPick,
        BlockActionKind.cast,
        BlockActionKind.observe,
      ];
    case RoutineKind.freePlay:
      return const [
        BlockActionKind.headcount,
        BlockActionKind.capture,
        BlockActionKind.observe,
        BlockActionKind.incident,
      ];
    case null:
      // A generic do-it activity.
      return const [
        BlockActionKind.runActivity,
        BlockActionKind.capture,
        BlockActionKind.observe,
        BlockActionKind.cast,
      ];
  }
}

/// Bind the pure action kinds to real launchers for THIS block. Every target is
/// a route that already exists (or the shared `showCastToRoom` chooser); a kind
/// whose context is missing (e.g. no `groupId`) is dropped so the tray never
/// offers a dead button.
List<BeatAction> blockActionsFor(
  BuildContext context, {
  required String blockId,
  required String? groupId,
  required String scheduleKind,
  required String title,
  required String? sessionSlug,
}) {
  final hasSession = (sessionSlug ?? '').trim().isNotEmpty;
  final kinds = blockActionKindsFor(
    scheduleKind: scheduleKind,
    title: title,
    hasSession: hasSession,
  );

  void go(String route) => unawaited(context.push(route));
  final out = <BeatAction>[];
  for (final k in kinds) {
    switch (k) {
      case BlockActionKind.checkIn:
        if (groupId == null) break;
        out.add(BeatAction(
          icon: Icons.how_to_reg_outlined,
          label: 'Check-in',
          onTap: () => go('/groups/$groupId/attendance'),
        ));
      case BlockActionKind.headcount:
        if (groupId == null) break;
        out.add(BeatAction(
          icon: Icons.groups_outlined,
          label: 'Headcount',
          onTap: () => go('/groups/$groupId/attendance'),
        ));
      case BlockActionKind.capture:
        out.add(BeatAction(
          icon: Icons.photo_camera_outlined,
          label: 'Capture',
          onTap: () => go('/captures/new'),
        ));
      case BlockActionKind.observe:
        out.add(BeatAction(
          icon: Icons.visibility_outlined,
          label: 'Observe',
          onTap: () => go('/observations/new'),
        ));
      case BlockActionKind.incident:
        out.add(BeatAction(
          icon: Icons.report_outlined,
          label: 'Incident',
          onTap: () => go('/incidents/new'),
        ));
      case BlockActionKind.message:
        out.add(BeatAction(
          icon: Icons.mail_outline,
          label: 'Message',
          onTap: () => go('/messages'),
        ));
      case BlockActionKind.pickup:
        out.add(BeatAction(
          icon: Icons.directions_walk_outlined,
          label: 'Pickup',
          onTap: () => go('/pickup'),
        ));
      case BlockActionKind.wordsPick:
        out.add(BeatAction(
          icon: Icons.bolt_outlined,
          label: 'Words',
          onTap: () => go('/action-words'),
        ));
      case BlockActionKind.runDeck:
        if (!hasSession) break;
        final slug = Uri.encodeQueryComponent(sessionSlug!.trim());
        final blk = Uri.encodeQueryComponent(blockId);
        out.add(BeatAction(
          icon: Icons.menu_book_outlined,
          label: 'Run deck',
          onTap: () => go('/session/run?slug=$slug&block=$blk'),
        ));
      case BlockActionKind.runActivity:
        out.add(BeatAction(
          icon: Icons.play_arrow_rounded,
          label: 'Run',
          onTap: () => unawaited(context.push('/arc', extra: title)),
        ));
      case BlockActionKind.cast:
        final mirror = hasSession
            ? '/session/run?slug=${Uri.encodeQueryComponent(sessionSlug!.trim())}'
                  '&block=${Uri.encodeQueryComponent(blockId)}'
            : '/run-day';
        out.add(BeatAction(
          icon: Icons.cast,
          label: 'Cast',
          onTap: () =>
              unawaited(showCastToRoom(context, mirrorRoute: mirror)),
        ));
      case BlockActionKind.tripBoard:
        out.add(BeatAction(
          icon: Icons.map_outlined,
          label: 'Trip board',
          onTap: () => go('/trips/$blockId'),
        ));
      case BlockActionKind.notify:
        if (groupId == null) break;
        out.add(BeatAction(
          icon: Icons.campaign_outlined,
          label: 'Notify',
          onTap: () => go('/recap?group=$groupId'),
        ));
    }
  }
  return out;
}
