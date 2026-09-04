import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/activity_runtime/activity_runners.dart';
import 'package:differentworld/features/activity_runtime/photo_turns_screen.dart';
import 'package:differentworld/features/curricula/photo_curriculum.dart';
import 'package:differentworld/features/curricula/session_script.dart';
import 'package:differentworld/features/curricula/session_scripts.dart';
import 'package:differentworld/features/guardians/guardians_providers.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/block_edit_screen.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/trip_map_tile.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/supplies/activity_supplies_providers.dart';
import 'package:differentworld/features/supplies/supplies_providers.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/bento_module.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Args for the Block Run Sheet route, passed via go_router `extra`.
/// Carries the whole [ScheduleBlock] so the sheet resolves its linked
/// activity → routine + supplies without a second fetch. (The block also
/// carries `groupId`, which the cast action needs.)
typedef BlockRunSheetArgs = ({ScheduleBlock block});

/// `/schedule/block/run` — a block's self-contained run sheet (docs/VISION.md
/// 2026-06-19: *"each block self-contained — all its info AND its actions,
/// together"*). Tapping a content-bearing schedule block opens THIS instead of
/// the edit page.
///
/// Top to bottom: the header (time · location · lead; the activity name; its
/// subtitle/prompt + an Edit pencil) → **The routine** (the activity's ordered
/// numbered steps) → **What you'll need** (the activity's supply pack list as
/// chips) → actions: a primary [Start {activity}] + secondary [Capture] +
/// [Cast to room].
///
/// Offline-first: every read is a Drift watch; nothing awaits the network.
class BlockRunSheetScreen extends ConsumerWidget {
  const BlockRunSheetScreen({required this.block, super.key});

  final ScheduleBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the linked activity (allActivities so an archived link still
    // resolves its name + routine). The block may be a bare/typed block with
    // no activity — the routine then reads off whatever the block names.
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final activity = block.activityId == null
        ? null
        : activities.where((a) => a.id == block.activityId).firstOrNull;

    // Resolve the curriculum session the block was stamped with (the same
    // 'Through My Eyes · S{N}' badge the schedule tile shows). When present,
    // the SESSION'S lesson drives the run sheet — its routine, its materials,
    // its big idea — because a curriculum block carries no activity and would
    // otherwise read empty. A block with no slug resolves null → every
    // session-driven branch below falls back to the unchanged activity path.
    final session = block.curriculumSessionSlug == null
        ? null
        : findSessionBySlug(block.curriculumSessionSlug!);

    // Effective location: the block's override, else the activity default.
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    final effectiveLocationId =
        block.locationOverrideId ?? activity?.defaultLocationId;
    final location = effectiveLocationId == null
        ? null
        : locations.where((l) => l.id == effectiveLocationId).firstOrNull;

    // The lead (planned, or the substitute when one's covering today).
    final members = ref.watch(membersInSpaceProvider).value ?? const <Member>[];
    final leadId = block.leadSubstituteMemberId ?? block.leadMemberId;
    final lead = leadId == null
        ? null
        : members.where((m) => m.id == leadId).firstOrNull;

    // The block's resolved title (same precedence as the agenda tile: the
    // typed title wins, else the activity name, else a kind fallback).
    final blockTitle = block.title?.trim() ?? '';
    final title = blockTitle.isNotEmpty
        ? blockTitle
        : (activity?.name ?? 'This block');

    // The header subtitle — what staff read for "what happens here". A
    // curriculum block leads with the session's big idea (its title as a
    // fallback); an ordinary block keeps the linked activity's description.
    final subtitle = session != null
        ? (session.bigIdea.trim().isNotEmpty
              ? session.bigIdea.trim()
              : session.title.trim())
        : activity?.description?.trim();

    final start = DateTime.tryParse(block.startAt)?.toLocal();
    final end = DateTime.tryParse(block.endAt)?.toLocal();
    final timeLabel = (start != null && end != null)
        ? '${timeOfDay(start)} – ${timeOfDay(end)}'
        : '';
    // time · location · lead — only the parts we have, joined by a dot.
    final metaParts = <String>[
      if (timeLabel.isNotEmpty) timeLabel,
      if (location != null) location.name,
      if (lead != null) lead.displayName,
    ];

    // The routine. A curriculum session's lesson takes PRECEDENCE: build its
    // ordered steps (setup → game rules → looking together → end ritual),
    // using the session's own text trimmed, skipping any empty field. Only
    // when there's no session do we read the linked activity's caps routine
    // (the unchanged path for an ordinary block).
    final routine = session != null
        ? _sessionRoutine(session)
        : activity == null
        ? const <String>[]
        : ref.watch(routineForActivityProvider(activity.id)).value ??
              const <String>[];

    // "Run" plumbing — mirrors the agenda tile exactly. The topic is the
    // activity name, else the resolved title; the activity's chosen runner
    // (if any) launches directly, else the generic `/arc` teaching arc.
    final runTopic = (activity?.name.trim().isNotEmpty ?? false)
        ? activity!.name.trim()
        : title.trim();
    final runner = activity == null
        ? null
        : runnerForSlug(
            Capabilities.fromJson(
              activity.capabilities,
            ).getString(ActivityCaps.runnerSlug),
          );
    final startLabel = activity != null
        ? 'Start ${activity.name.trim()}'
        : 'Start';

    // Is this a "Through My Eyes" photo block? Yes when the block was stamped
    // with a `photo.` curriculum slug, OR its linked activity runs as the
    // photo studio / photo turns (read off the already-resolved `runner`).
    // Those are the blocks where the primary way to run a session on one
    // shared device is the per-child timed turns.
    final isPhotoBlock =
        (block.curriculumSessionSlug?.startsWith('photo.') ?? false) ||
        runner?.slug == 'photo' ||
        runner?.slug == 'photo-turns';
    // The mission carried into each child's locked turn — the session's big
    // idea (its title as a fallback), else the resolved block title.
    final photoTurnsPrompt = session != null
        ? (session.bigIdea.trim().isNotEmpty
              ? session.bigIdea.trim()
              : session.title.trim())
        : title.trim();
    // The per-child turn length — the session's shooting minutes when a session
    // is resolved (so a 12-min "Light Chasers" turn ≠ a 5-min default), else
    // null → the turns screen falls back to its own 5-minute default.
    final photoTurnsMinutes = session == null
        ? null
        : sessionShootMinutes(session);

    // EVERY block kind now runs from the SAME bento tray — one no-hunting
    // dashboard, the tools assembled per kind (docs/VISION.md: "all what is
    // needed are in that bento"). The shared header + grid live in [_RunBento];
    // each branch below builds only the tiles that block earns.
    final eyebrow = _eyebrowFor(block, session, runner);

    // ── PHOTO / "Through My Eyes" — the 7-tile photo tray, unchanged ──────
    if (isPhotoBlock) {
      // The beat-by-beat session presenter is offered only when this block's
      // stamped curriculum slug has a written script (all 6 sessions today).
      // The slug — not the PhotoSession summary — is the contract
      // scriptForSession joins on, so resolve straight off the block's slug.
      // That same resolved script also drives the "How it runs" + "You'll need"
      // tiles below (the real beat arc + prep materials) instead of the stale
      // PhotoSession summary, so a scripted block reads its actual hour.
      final scriptSlug = block.curriculumSessionSlug;
      final script = scriptSlug == null ? null : scriptForSession(scriptSlug);
      // "Review & favorites" only earns a tile once there's something to review —
      // before the first shot there's nothing to look back at, so omit it.
      final hasPhotos =
          (ref.watch(attachmentsForBlockProvider(block.id)).value ??
                  const <Attachment>[])
              .isNotEmpty;
      return _PhotoRunBento(
        block: block,
        session: session,
        script: script,
        eyebrow: eyebrow,
        title: title,
        metaParts: metaParts,
        routine: routine,
        hasPhotos: hasPhotos,
        onEdit: () => _openEdit(context),
        // Only non-null when a script exists → the tile renders only then.
        onRunSession: script != null
            ? () => _runSession(context, slug: scriptSlug!)
            : null,
        onRunTurns: () => _runPhotoTurns(
          context,
          prompt: photoTurnsPrompt,
          minutes: photoTurnsMinutes,
        ),
        onCapture: () => _capture(context),
        onCast: () => _cast(context, ref),
        onReview: () => _openReview(context),
      );
    }

    // ── BREAK / CLOSED — nothing to run, so a calm minimal tray ───────────
    // A break or a closed day has no activity to start; forcing a "Start"
    // hero would be a dead promise. Instead: a quiet note + a single
    // "Capture a moment" tile (a snack-time photo is still worth keeping).
    final isQuiet =
        block.kind == BlockKind.breakBlock || block.kind == BlockKind.closed;
    if (isQuiet) {
      final isClosed = block.kind == BlockKind.closed;
      return _RunBento(
        eyebrow: eyebrow,
        title: title,
        meta: metaParts.join('  ·  '),
        onEdit: () => _openEdit(context),
        tiles: [
          BentoTile(
            id: 'quiet-note',
            span: const BentoSpan.wide(),
            child: _QuietNoteTile(
              icon: isClosed
                  ? Icons.event_busy_outlined
                  : Icons.local_cafe_outlined,
              text: isClosed
                  ? "The program's closed — nothing scheduled to run."
                  : 'A break — no activity to run, just a breather.',
            ),
          ),
          // Even on a break a moment is worth keeping — the one action that
          // still makes sense.
          BentoTile(
            id: 'capture',
            span: const BentoSpan.wide(),
            child: _SimpleToolTile(
              icon: Icons.photo_camera_outlined,
              title: 'Capture a moment',
              subtitle: 'Snap a quick one',
              onTap: () => _capture(context),
            ),
          ),
        ],
      );
    }

    // ── ACTIVITY / DISCUSSION / ordinary — the common run tray ────────────
    // The generic tiles every runnable block earns. A field TRIP shares all of
    // these AND appends its own ("Where" + the door into the headcount / slips
    // / vehicles screen) at the tail, so a counselor never hunts for trip prep.

    // Per-block gates — show ONLY what's necessary for THIS block. The photo +
    // break/closed kinds already returned above, so the only kinds reaching
    // this generic tray are on-site activities and field trips.
    //
    // CAST — there's a room to mirror to only for an on-site activity; a field
    // trip has no in-room screen to cast onto, so its tile would be a dead
    // promise. (Photo blocks cast too, but they take the photo tray above and
    // keep their own Cast tile.)
    final canCast = block.kind == BlockKind.onSite || isPhotoBlock;
    // YOU'LL NEED — there's a packing list only when the linked activity has
    // supply links OR the session/script names materials. Nothing to bring →
    // omit the tile rather than show a hollow "no supplies yet" card.
    final hasSupplies =
        (activity != null &&
            (ref.watch(activitySupplyLinksProvider(activity.id)).value ??
                    const <ActivitySupply>[])
                .isNotEmpty) ||
        (session?.materials.trim().isNotEmpty ?? false) ||
        (() {
          final slug = block.curriculumSessionSlug;
          final script = slug == null ? null : scriptForSession(slug);
          return script != null && _scriptNeeds(script).trim().isNotEmpty;
        }());

    final tiles = <BentoTile>[
      // HERO — the primary verb: start the linked runner, else the teaching
      // arc. Full-width warm signal so it's unmistakably the thing to tap.
      BentoTile(
        id: 'start',
        span: const BentoSpan.wide(),
        child: _HeroActionTile(
          icon: Icons.play_arrow_rounded,
          title: startLabel,
          subtitle: (subtitle != null && subtitle.isNotEmpty)
              ? subtitle
              : (runner != null
                    ? 'Open the activity on this device'
                    : 'Walk the group through it'),
          onTap: () => _start(context, runner: runner, topic: runTopic),
        ),
      ),
      // How it runs — only when there's a routine to show (empty → omit; the
      // top-right Edit covers authoring, no dead "no steps yet" tile).
      if (routine.isNotEmpty)
        BentoTile(
          id: 'how-it-runs',
          span: const BentoSpan(phone: 1),
          child: _HowItRunsTile(steps: routine),
        ),
      // You'll need — the activity's supply pack (live chips), else the
      // session's materials line. Only when there's genuinely something to
      // bring (supply links / session materials); nothing → omit the tile.
      if (hasSupplies)
        BentoTile(
          id: 'needs',
          span: const BentoSpan(phone: 1),
          child: _SuppliesTile(activity: activity, session: session),
        ),
      // Cast to room — only when there's a room to mirror to (an on-site
      // activity). A field trip has no in-room screen, so its tile is dropped.
      if (canCast)
        BentoTile(
          id: 'cast',
          span: const BentoSpan(phone: 1),
          child: _SimpleToolTile(
            icon: Icons.cast,
            title: 'Cast to room',
            subtitle: 'Mirror to the big screen',
            onTap: () => _cast(context, ref),
          ),
        ),
      // Capture — always: a moment is worth keeping on any block.
      BentoTile(
        id: 'capture',
        span: const BentoSpan(phone: 1),
        child: _SimpleToolTile(
          icon: Icons.photo_camera_outlined,
          title: 'Capture',
          subtitle: 'Snap a quick one',
          onTap: () => _capture(context),
        ),
      ),
      // TRIP appends its own surfaces — the live MAP (its hero: destination +
      // "we're here" pins, GPS pin-drop + directions), then the three trip
      // TOOLS (count heads · emergency · notify families), then the door into
      // the full headcount / slips / vehicles screen. The map folds in the old
      // "Where" line as its caption, so there's no separate destination tile.
      if (block.kind == BlockKind.fieldTrip) ...[
        BentoTile(
          id: 'trip-map',
          span: const BentoSpan.wide(),
          child: TripMapTile(
            block: block,
            // The caption name: the activity-resolved block title (the trip's
            // own name), so "Lincoln Park Zoo" sits under the map. The map's
            // own watch supplies the live address line beneath it.
            destinationName: title,
          ),
        ),
        // Count heads — a glance (live N) + the door into the headcount
        // roll-call that already lives on the trip screen. Not a new store.
        BentoTile(
          id: 'trip-headcount',
          span: const BentoSpan(phone: 1),
          child: _TripHeadcountTile(
            block: block,
            onTap: () => _openTrip(context),
          ),
        ),
        // Emergency — the safety one-tap: each child's allergies / medical
        // note + a one-tap call to a linked guardian. Strong error tone.
        BentoTile(
          id: 'trip-emergency',
          span: const BentoSpan(phone: 1),
          child: _TripEmergencyTile(
            block: block,
            onTap: () => _openEmergency(context),
          ),
        ),
        // Notify families — open the daily recap composer for this cohort
        // (the existing send-the-family-their-child's-day surface). The
        // trip's "Arrived safe" / "Heading back" note rides that flow.
        BentoTile(
          id: 'trip-notify',
          span: const BentoSpan(phone: 1),
          child: _SimpleToolTile(
            icon: Icons.outgoing_mail,
            title: 'Notify families',
            subtitle: '“Arrived safe” · “Heading back”',
            semanticLabel:
                'Notify families — send the cohort a quick update like '
                'arrived safe or heading back',
            onTap: () => _openRecap(context),
          ),
        ),
        BentoTile(
          id: 'trip-prep',
          span: const BentoSpan(phone: 1),
          child: _TripPrepTile(
            block: block,
            onTap: () => _openTrip(context),
          ),
        ),
      ],
    ];

    return _RunBento(
      eyebrow: eyebrow,
      title: title,
      meta: metaParts.join('  ·  '),
      onEdit: () => _openEdit(context),
      tiles: tiles,
    );
  }

  /// Open the field-trip prep screen for this block — the full headcount /
  /// slips / vehicles surface (`/trips/:blockId`). The bento's door into it.
  void _openTrip(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(context.push('/trips/${block.id}'));
  }

  /// Open the trip's EMERGENCY card — each roster child's allergies / medical
  /// note + a one-tap call to a linked guardian. Pushed imperatively (the way
  /// `_openReview` opens the turns review) so it needs no router wiring; the
  /// screen reads everything live off Drift watches, so it works offline.
  void _openEmergency(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _EmergencyContactsScreen(groupId: block.groupId),
        ),
      ),
    );
  }

  /// Open the daily RECAP composer for this trip's cohort — the existing
  /// "send each family their child's day" surface (`/recap?group=…`). The
  /// trip's "Arrived safe" / "Heading back" note rides that flow; the
  /// composer takes no prefill hint today, so we just open it scoped to the
  /// group (noted in the report).
  void _openRecap(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(context.push('/recap?group=${block.groupId}'));
  }

  void _openEdit(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    // Reuse the existing block edit page. Args mirror what the schedule
    // screen's `_openBlockSheet` passes.
    final BlockEditArgs args = (
      groupId: block.groupId,
      defaultStart: DateTime.parse(block.startAt).toLocal(),
      existing: block,
      prefillCurriculumSlug: null,
    );
    unawaited(context.push<void>('/schedule/block', extra: args));
  }

  /// Start the activity — the SAME runner-slug / teaching-arc launch the
  /// agenda tile's "Run" button used (now folded into the run sheet).
  void _start(
    BuildContext context, {
    required ActivityRunner? runner,
    required String topic,
  }) {
    unawaited(HapticFeedback.selectionClick());
    if (runner != null) {
      // Seed the on-screen prompt for runners that accept one (Photo Studio).
      final dest = runner.takesPrompt
          ? Uri(
              path: runner.route,
              queryParameters: {'prompt': topic},
            ).toString()
          : runner.route;
      unawaited(context.push(dest));
    } else {
      unawaited(context.push('/arc', extra: topic));
    }
  }

  /// Launch the beat-by-beat SESSION RUN PRESENTER for this block's stamped
  /// curriculum session — the host runs the scripted hour beat by beat (one
  /// calm slide each), distinct from "Run photo turns" (the just-shooting
  /// path). Only offered when `scriptForSession(slug)` resolves a script;
  /// `block=` scopes the game-beat photo-turns handoff back to this block.
  void _runSession(BuildContext context, {required String slug}) {
    unawaited(HapticFeedback.selectionClick());
    final dest = Uri(
      path: '/session/run',
      queryParameters: {'slug': slug, 'block': block.id},
    ).toString();
    unawaited(context.push(dest));
  }

  /// Launch the per-child timed photo TURNS for this block — the roster scopes
  /// to the block's group and every shot is tagged with the block id (the
  /// already-built `/activity/photo-turns` surface). The `prompt` becomes the
  /// mission shown inside each child's locked turn; `minutes` (the session's
  /// shooting figure, when one was resolved) sets that turn's countdown.
  void _runPhotoTurns(
    BuildContext context, {
    required String prompt,
    int? minutes,
  }) {
    unawaited(HapticFeedback.selectionClick());
    final dest = Uri(
      path: '/activity/photo-turns',
      queryParameters: {
        'block': block.id,
        'prompt': prompt,
        if (minutes != null) 'minutes': '$minutes',
      },
    ).toString();
    unawaited(context.push(dest));
  }

  /// Open the timed-turns REVIEW for this block directly — the warm "pick your
  /// favorites" screen, scoped to this block's photos. Reuses the same
  /// [PhotoTurnsReviewScreen] the turns flow ends in (pushed imperatively, the
  /// way the turns picker opens it), so review is reachable as its own tool from
  /// the tray without first stepping through a turn.
  void _openReview(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => PhotoTurnsReviewScreen(blockId: block.id),
        ),
      ),
    );
  }

  void _capture(BuildContext context) {
    unawaited(HapticFeedback.selectionClick());
    unawaited(context.push('/captures/new'));
  }

  /// Cast this block to the room — the SAME per-block cast the schedule deck's
  /// slide uses: project the cohort's LIVE block to the TV, which follows the
  /// day on its own.
  void _cast(BuildContext context, WidgetRef ref) {
    unawaited(
      showCastToRoom(
        context,
        ref,
        mirrorRoute: '/present-room/${block.groupId}',
        mirrorLabel: 'Show this block on the screen',
        mirrorSubtitle:
            "Put the live block on the room's TV — it follows the day on its "
            'own.',
      ),
    );
  }
}

/// The universal BENTO run-sheet shell — every block kind runs the hour from
/// THIS one tray (docs/VISION.md: *"all what is needed are in that bento… i
/// don't want to hunt for buttons"*). It owns the chrome (the `Edit` pill + the
/// `/schedule` back-fallback), the capped + centred header, and the responsive
/// [BentoGrid]; the CALLER assembles the [tiles] for that block kind. The photo
/// branch ([_PhotoRunBento]) is one specialisation; activity / trip / break /
/// closed each build their own tile list and hand it here.
class _RunBento extends StatelessWidget {
  const _RunBento({
    required this.eyebrow,
    required this.title,
    required this.meta,
    required this.tiles,
    required this.onEdit,
  });

  final String eyebrow;
  final String title;
  final String meta;
  final List<BentoTile> tiles;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      backFallbackRoute: '/schedule',
      actions: [
        IconButton(
          tooltip: 'Edit block',
          icon: const Icon(Icons.edit_outlined),
          onPressed: onEdit,
        ),
      ],
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          // Cap + center so the header + bento don't stretch edge-to-edge on a
          // desktop window (matches the subject-detail treatment).
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.splitMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BentoHeader(eyebrow: eyebrow, title: title, meta: meta),
                  BentoGrid(tiles: tiles),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The photo SPECIALISATION of [_RunBento] — the 7-tile "Through My Eyes" tray
/// (the approved mockup), unchanged: a warm SIGNAL hero "Run photo turns" → a
/// 2-col bento of Whose turn (live) · How it runs · Cast to room · Review &
/// favorites · Capture · You'll need (a quiet INFO tile). Each tile is a real
/// dispatch; the live tiles read Drift watches. Assembles its tiles, then hands
/// them to the shared shell.
class _PhotoRunBento extends StatelessWidget {
  const _PhotoRunBento({
    required this.block,
    required this.session,
    required this.script,
    required this.eyebrow,
    required this.title,
    required this.metaParts,
    required this.routine,
    required this.hasPhotos,
    required this.onEdit,
    required this.onRunSession,
    required this.onRunTurns,
    required this.onCapture,
    required this.onCast,
    required this.onReview,
  });

  final ScheduleBlock block;
  final PhotoSession? session;

  /// The block's resolved SESSION SCRIPT when its slug has a written one
  /// (all 6 today), else null. When present it drives the "How it runs" +
  /// "You'll need" tiles — the real beat arc + prep materials — instead of the
  /// stale PhotoSession summary. Null → both tiles keep the summary path.
  final SessionScript? script;

  final String eyebrow;
  final String title;
  final List<String> metaParts;

  /// The session's ordered lesson steps (the full-text routine). Drives the
  /// "How it runs" tile's fallback when the session can't supply the short
  /// four-beat captions.
  final List<String> routine;

  /// Whether this block already has any photos tagged to it. Computed at the
  /// assembly point (where `ref` is available) so this stateless bento can gate
  /// the "Review & favorites" tile without a watch of its own. False → that
  /// tile is omitted (nothing to review before the first shot).
  final bool hasPhotos;

  final VoidCallback onEdit;

  /// Launch the beat-by-beat session presenter. Null when this block's session
  /// has no written script — the "Run the session" tile then doesn't render
  /// (no dead promise), and "Run photo turns" stays the way to run the hour.
  final VoidCallback? onRunSession;

  final VoidCallback onRunTurns;
  final VoidCallback onCapture;
  final VoidCallback onCast;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    // "You'll need" — when this block has a written SCRIPT, the materials come
    // from the script's prep beat (the host's "before they arrive" list); else
    // the PhotoSession's plain-prose materials, else a calm generic.
    final scriptForTiles = script;
    final needs = scriptForTiles != null
        ? _scriptNeeds(scriptForTiles)
        : (session != null && session!.materials.trim().isNotEmpty)
        ? session!.materials.trim()
        : '1 device · a screen · timer';
    // "How it runs" — when a SCRIPT exists, the real beat arc (its content-beat
    // titles in order); else the short four-beat summary steps (hand over →
    // play → look → pick), each gated on the PhotoSession having that field.
    final steps = scriptForTiles != null
        ? _scriptRunSteps(scriptForTiles)
        : _runsSteps(session, routine);

    final tiles = <BentoTile>[
      // RUN THE SESSION — the beat-by-beat presenter, offered ONLY when this
      // session has a written script. The lead tile when present: it's the
      // "run the whole scripted hour" path (vs "Run photo turns", the just-
      // shooting path below). A distinct full-width signal tile.
      if (onRunSession != null)
        BentoTile(
          id: 'run-session',
          span: const BentoSpan.wide(),
          child: _HeroActionTile(
            icon: Icons.menu_book_outlined,
            title: 'Run the session',
            subtitle: 'Beat by beat — the full scripted hour',
            flowSteps: const ['the hook', 'the games', 'the close'],
            semanticLabel:
                'Run the session — the full scripted hour, beat by beat',
            onTap: onRunSession!,
          ),
        ),
      // HERO — full width, the primary way to just SHOOT (no script). When a
      // script exists this sits under "Run the session" as the lighter path.
      BentoTile(
        id: 'run-turns',
        span: const BentoSpan.wide(),
        child: _HeroActionTile(
          icon: Icons.play_arrow_rounded,
          title: 'Run photo turns',
          subtitle: 'One phone, one child — 5 min each',
          flowSteps: const ['pick a child', '5 locked min', 'give it back'],
          semanticLabel:
              'Run photo turns — one phone, one child, five minutes each',
          onTap: onRunTurns,
        ),
      ),
      // Whose turn — LIVE: {done} of {N} + roster dots. Tap → photo turns.
      BentoTile(
        id: 'whose-turn',
        span: const BentoSpan(phone: 1),
        child: _WhoseTurnTile(block: block, onTap: onRunTurns),
      ),
      // How it runs — the session's routine as short numbered steps.
      BentoTile(
        id: 'how-it-runs',
        span: const BentoSpan(phone: 1),
        child: _HowItRunsTile(steps: steps),
      ),
      // Cast to room — mirror to the big screen.
      BentoTile(
        id: 'cast',
        span: const BentoSpan(phone: 1),
        child: _SimpleToolTile(
          icon: Icons.cast,
          title: 'Cast to room',
          subtitle: 'Mirror to the big screen',
          onTap: onCast,
        ),
      ),
      // Review & favorites — LIVE photo count. Only once there's at least one
      // shot to look back at; before then there's nothing to review, so omit.
      if (hasPhotos)
        BentoTile(
          id: 'review',
          span: const BentoSpan(phone: 1),
          child: _ReviewTile(block: block, onTap: onReview),
        ),
      // Capture — a quick one-off snap.
      BentoTile(
        id: 'capture',
        span: const BentoSpan(phone: 1),
        child: _SimpleToolTile(
          icon: Icons.photo_camera_outlined,
          title: 'Capture',
          subtitle: 'Snap a quick one',
          onTap: onCapture,
        ),
      ),
      // You'll need — an INFO tile (not tappable), the session's materials.
      BentoTile(
        id: 'needs',
        span: const BentoSpan(phone: 1),
        child: _NeedsTile(text: needs),
      ),
    ];

    return _RunBento(
      eyebrow: eyebrow,
      title: title,
      meta: metaParts.join('  ·  '),
      onEdit: onEdit,
      tiles: tiles,
    );
  }
}

/// The run sheet's eyebrow — the small tracked label over the title. A photo /
/// curriculum block reads "through my eyes · session {N}" (or "photo session"
/// un-stamped); a field trip reads "field trip"; a break / closed day name
/// themselves; everything else takes its launchable runner's label, else the
/// neutral "activity block". Lowercase by design (the [_BentoHeader] tracks it).
String _eyebrowFor(
  ScheduleBlock block,
  PhotoSession? session,
  ActivityRunner? runner,
) {
  if (session != null) {
    return 'through my eyes · session ${session.number}';
  }
  if ((block.curriculumSessionSlug?.startsWith('photo.') ?? false) ||
      runner?.slug == 'photo' ||
      runner?.slug == 'photo-turns') {
    return 'photo session';
  }
  switch (block.kind) {
    case BlockKind.fieldTrip:
      return 'field trip';
    case BlockKind.breakBlock:
      return 'break';
    case BlockKind.closed:
      return 'closed';
  }
  // On-site / ordinary: lead with the runner's own name when one's linked.
  return runner != null ? runner.label.toLowerCase() : 'activity block';
}

/// The bento header — eyebrow (small tracked label) over the Fraunces session
/// title, then the time · group · count meta. The enclosing [_RunBento]'s
/// `SafeArea(top: true)` is what actually clears the top chrome (it consumes the
/// band EdgeScaffold inflates into `MediaQuery.padding.top`); the read below is
/// then ~0 and only adds breathing room — kept so the header still self-clears
/// if ever placed without that SafeArea. Don't strip the SafeArea assuming this
/// header covers it.
class _BentoHeader extends StatelessWidget {
  const _BentoHeader({
    required this.eyebrow,
    required this.title,
    required this.meta,
  });

  final String eyebrow;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chromeReservation = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.only(top: chromeReservation + 8, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(title, style: theme.textTheme.headlineSmall),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The HERO tile — the one warm signal-tinted card per tray, carrying the
/// block's primary verb (run the photo turns, start the activity, …). Tertiary
/// container is the app's softer "featured" tint; the foreground rides
/// `onTertiaryContainer` so text + icons always clear AA on it. [flowSteps],
/// when given, draws the 3-step flow strip (photo: pick a child → 5 locked min →
/// give it back) that shows the shape of the action at a glance; an ordinary
/// activity hero omits it and reads title + subtitle only.
class _HeroActionTile extends StatelessWidget {
  const _HeroActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.flowSteps = const <String>[],
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Optional pill-strip beneath the title (e.g. the photo turn's three beats).
  /// Empty → no strip.
  final List<String> flowSteps;

  /// Spoken label; defaults to "{title} — {subtitle}".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onTertiaryContainer;
    return BentoModule(
      background: scheme.tertiaryContainer,
      foreground: fg,
      onTap: onTap,
      semanticLabel: semanticLabel ?? '$title — $subtitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoModuleIcon(icon: icon, tint: scheme.tertiary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      // Full-strength fg (the seeded AA pair); the size + weight
                      // step down from the title carries the hierarchy, not a
                      // dimmed alpha (which would risk failing contrast).
                      style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg.withValues(alpha: 0.7)),
            ],
          ),
          if (flowSteps.isNotEmpty) ...[
            const SizedBox(height: 14),
            _FlowStrip(
              steps: flowSteps,
              fill: scheme.tertiary,
              onFill: scheme.onTertiary,
              connector: fg.withValues(alpha: 0.55),
            ),
          ],
        ],
      ),
    );
  }
}

/// The hero's 3-step flow strip — pill · arrow · pill · arrow · pill, wrapping
/// on narrow widths. Pills use the tile's accent fill with its paired
/// foreground (never colour alone — the label carries the meaning).
class _FlowStrip extends StatelessWidget {
  const _FlowStrip({
    required this.steps,
    required this.fill,
    required this.onFill,
    required this.connector,
  });

  final List<String> steps;
  final Color fill;
  final Color onFill;
  final Color connector;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_right_alt, size: 16, color: connector),
          ),
        );
      }
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            steps[i],
            style: theme.textTheme.labelMedium?.copyWith(
              color: onFill,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: children,
    );
  }
}

/// "Whose turn" — LIVE. Reads `attachmentsForBlockProvider(block.id)` for the
/// set of children who've SHOT (distinct `captured_by_subject_id`) and
/// `subjectsInGroupProvider(block.groupId)` for the roster size N, so the tile
/// shows "{done} of {N} had a turn" + a row of roster dots (done filled, the
/// rest faint). Tap → the photo-turns picker.
class _WhoseTurnTile extends ConsumerWidget {
  const _WhoseTurnTile({required this.block, required this.onTap});

  final ScheduleBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final roster = _rosterOf(ref, block.groupId);
    final shots =
        ref.watch(attachmentsForBlockProvider(block.id)).value ??
        const <Attachment>[];

    // {done} = distinct children who appear as the SHOOTER of any shot tagged to
    // this block. {N} = roster size. Both derived cheaply from the two watches.
    final shooters = <String>{};
    for (final a in shots) {
      final by = a.capturedBySubjectId;
      if (by != null) shooters.add(by);
    }
    final n = roster.length;
    final done = roster.where((s) => shooters.contains(s.id)).length;

    final fg = scheme.onSecondaryContainer;
    return BentoModule(
      background: scheme.secondaryContainer,
      foreground: fg,
      onTap: onTap,
      semanticLabel: 'Whose turn — $done of $n had a turn',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileHeader(
            icon: Icons.groups_outlined,
            tint: scheme.secondary,
            title: 'Whose turn',
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$done',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: ' of $n',
                  style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                ),
              ],
            ),
          ),
          Text(
            'had a turn',
            // Full-strength fg (the seeded AA pair on secondaryContainer); the
            // smaller body size carries the hierarchy, not a dimmed alpha.
            style: theme.textTheme.bodySmall?.copyWith(color: fg),
          ),
          if (n > 0) ...[
            const SizedBox(height: 10),
            _RosterDots(total: n, done: done, color: scheme.secondary),
          ],
        ],
      ),
    );
  }
}

/// A compact row of dots — one per roster member, the first `done` filled and
/// the rest faint. Caps at a sensible width so a big roster wraps rather than
/// overflowing the tile. Decorative (the count above is the real signal), so
/// it's excluded from semantics.
class _RosterDots extends StatelessWidget {
  const _RosterDots({
    required this.total,
    required this.done,
    required this.color,
  });

  final int total;
  final int done;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: i < done ? color : color.withValues(alpha: 0.28),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

/// "How it runs" — the session's routine as short numbered steps. An INFO tile
/// (NOT tappable — reference, not an action), neutral-filled so the hero stays
/// the one warm thing on the tray.
class _HowItRunsTile extends StatelessWidget {
  const _HowItRunsTile({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: 'How it runs: ${steps.join(', ')}',
      // Info-only tile: a Material SURFACE with no InkWell — reading the steps
      // is the point, there's nothing to tap. Don't add an onTap here.
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  BentoModuleIcon(
                    icon: Icons.format_list_numbered,
                    tint: scheme.surfaceContainerLow,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'How it runs',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '${i + 1} · ${steps[i]}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Review & favorites" — LIVE photo count. Reads
/// `attachmentsForBlockProvider(block.id)` for "{m} photos"; tap → the review
/// screen.
class _ReviewTile extends ConsumerWidget {
  const _ReviewTile({required this.block, required this.onTap});

  final ScheduleBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count =
        ref.watch(attachmentsForBlockProvider(block.id)).value?.length ?? 0;
    return BentoModule(
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
      onTap: onTap,
      semanticLabel: count == 0
          ? 'Review and favorites'
          : 'Review and favorites — $count photos',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BentoModuleIcon(
                icon: Icons.favorite_outline,
                tint: scheme.surfaceContainerLow,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Review & favorites',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Look back · pick the keepers',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(height: 3),
            Text(
              count == 1 ? '1 photo' : '$count photos',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The shared tile header — a [BentoModuleIcon] + a bold one-line title. Every
/// run-sheet tile opens with this row; the icon tint (and optionally the title
/// color) is the only thing that varies per tile.
class _TileHeader extends StatelessWidget {
  const _TileHeader({
    required this.icon,
    required this.tint,
    required this.title,
    this.titleColor,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        BentoModuleIcon(icon: icon, tint: tint),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: titleColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// A plain neutral tool tile — an icon, a title, and a one-line subtitle, the
/// whole card tapping its action. Used for Cast + Capture + the trip tools.
/// [semanticLabel] overrides the default "$title — $subtitle" announcement;
/// [footer] appends extra lines under the subtitle (e.g. the trip-prep roster
/// count).
class _SimpleToolTile extends StatelessWidget {
  const _SimpleToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.semanticLabel,
    this.footer = const <Widget>[],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? semanticLabel;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return BentoModule(
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurface,
      onTap: onTap,
      semanticLabel: semanticLabel ?? '$title — $subtitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileHeader(
            icon: icon,
            tint: scheme.surfaceContainerLow,
            title: title,
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          ...footer,
        ],
      ),
    );
  }
}

/// The shared "You'll need" INFO shell — a quiet outlined card (NOT tappable)
/// with the checklist header, wrapping whatever content the caller supplies.
/// Reads as reference, not an action, so it never looks like a dead-tap button.
class _YoullNeedShell extends StatelessWidget {
  const _YoullNeedShell({required this.semanticLabel, required this.child});

  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TileHeader(
                icon: Icons.checklist_outlined,
                tint: scheme.surfaceContainerHighest,
                title: "You'll need",
                titleColor: scheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// "You'll need" — an INFO tile carrying the session's materials line.
class _NeedsTile extends StatelessWidget {
  const _NeedsTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return _YoullNeedShell(
      semanticLabel: "You'll need: $text",
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// "You'll need" for a generic / activity block — an INFO tile (NOT tappable):
/// the activity's supply pack as wrapped name chips when one's linked, else the
/// session's plain-prose materials, else a calm generic. Mirrors [_NeedsTile]'s
/// dashed-outline "reference, not an action" look so it never reads as a dead
/// button. Live: the name chips read the activity's supply links + the supply
/// catalog (the same `activitySupplyLinksProvider` + `suppliesProvider` reads).
class _SuppliesTile extends ConsumerWidget {
  const _SuppliesTile({required this.activity, required this.session});

  final Activity? activity;
  final PhotoSession? session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Resolve the activity's supply pack → ordered display names. Empty when no
    // activity, no links, or the catalog hasn't synced the names yet.
    final names = <String>[];
    if (activity != null) {
      final links =
          ref.watch(activitySupplyLinksProvider(activity!.id)).value ??
          const <ActivitySupply>[];
      final supplies = ref.watch(suppliesProvider).value ?? const <Supply>[];
      final nameById = {for (final s in supplies) s.id: s.name};
      for (final l in links) {
        final name = nameById[l.supplyId];
        if (name == null) continue;
        final qty = (l.quantity ?? 1).round();
        names.add(qty > 1 ? '$name · $qty' : name);
      }
    }

    // The fallback prose line when there are no resolved supply chips: the
    // session's materials, else a calm generic that points at where to author.
    final fallback = (session != null && session!.materials.trim().isNotEmpty)
        ? session!.materials.trim()
        : (activity == null
              ? 'Link an activity to pull in its supply list.'
              : 'No supplies on this activity yet.');

    final semantic = names.isEmpty
        ? "You'll need: $fallback"
        : "You'll need: ${names.join(', ')}";

    return _YoullNeedShell(
      semanticLabel: semantic,
      child: names.isEmpty
          ? Text(
              fallback,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          : Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in names)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      n,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// "Trip prep" — the door into the full field-trip screen (headcount, slips,
/// vehicles) at `/trips/:blockId`. Live: shows the roster size so a counselor
/// knows how many children the trip covers before opening the prep. Tap → the
/// trip screen (where the per-child slip + vehicle detail lives).
class _TripPrepTile extends ConsumerWidget {
  const _TripPrepTile({required this.block, required this.onTap});

  final ScheduleBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final n = _rosterOf(ref, block.groupId).length;

    return _SimpleToolTile(
      icon: Icons.fact_check_outlined,
      title: 'Trip prep',
      subtitle: 'Headcount · slips · vehicles',
      onTap: onTap,
      semanticLabel: 'Trip prep — headcount, permission slips, and vehicles',
      footer: [
        if (n > 0) ...[
          const SizedBox(height: 3),
          Text(
            n == 1 ? '1 child on the roster' : '$n children on the roster',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

/// "Count heads" — a glance + a door. Shows the live roster size N and the
/// three checkpoints the trip screen's headcount roll-call already covers
/// (at leaving · arrived · before back), then taps INTO that screen. This is
/// deliberately NOT a new checkpoint store — the count lives on the trip
/// screen (`TripHeadcountSection`); this tile is the entry point + the glance.
class _TripHeadcountTile extends ConsumerWidget {
  const _TripHeadcountTile({required this.block, required this.onTap});

  final ScheduleBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = _rosterOf(ref, block.groupId).length;
    final kidsLabel = n == 1 ? '1 kid' : '$n kids';

    return _SimpleToolTile(
      icon: Icons.groups_2_outlined,
      title: 'Count heads',
      subtitle: '$kidsLabel · at leaving · arrived · before back',
      onTap: onTap,
      semanticLabel:
          'Count heads — $kidsLabel, at leaving, arrived, and before back',
    );
  }
}

/// "Emergency" — the safety one-tap. A strong error-toned tile carrying the
/// count of roster kids who have an allergy / medical note, tapping into the
/// [_EmergencyContactsScreen] (per-child medical + a one-tap call to a linked
/// guardian). The one tile on the trip tray that earns the error container —
/// it's the "something's wrong, who do I call" card.
class _TripEmergencyTile extends ConsumerWidget {
  const _TripEmergencyTile({required this.block, required this.onTap});

  final ScheduleBlock block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final roster = _rosterOf(ref, block.groupId);
    // {k} = roster kids with a non-empty allergy OR medical-conditions note.
    // Allergies ride their own `subjects.allergies` column; medical conditions
    // live in the caps bag (SubjectCaps.medicalConditions).
    final k = roster.where(_hasMedicalNote).length;
    final subtitle = k == 0
        ? 'Who to call'
        : '${k == 1 ? '1 allergy' : '$k allergies'} · who to call';

    // Error container is the seeded "danger" pair — onErrorContainer always
    // clears AA on it, so the foreground rides that the same way the hero
    // rides onTertiaryContainer.
    final fg = scheme.onErrorContainer;
    return BentoModule(
      background: scheme.errorContainer,
      foreground: fg,
      onTap: onTap,
      semanticLabel: 'Emergency — $subtitle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileHeader(
            icon: Icons.emergency_outlined,
            tint: scheme.error,
            title: 'Emergency',
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            // Full-strength fg (the seeded AA pair on errorContainer); size
            // carries the hierarchy, not a dimmed alpha that could fail AA.
            style: theme.textTheme.bodyMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// The live roster for a cohort — the shared `subjectsInGroupProvider` watch
/// every trip tile leans on, empty until the stream delivers.
List<Subject> _rosterOf(WidgetRef ref, String groupId) {
  return ref.watch(subjectsInGroupProvider(groupId)).value ?? const <Subject>[];
}

/// True when a subject carries any allergy or medical-conditions note. Drives
/// the emergency tile's count + the per-child medical line on the screen.
bool _hasMedicalNote(Subject s) {
  final allergies = s.allergies?.trim() ?? '';
  final conditions =
      s.caps.getString(SubjectCaps.medicalConditions)?.trim() ?? '';
  return allergies.isNotEmpty || conditions.isNotEmpty;
}

/// The EMERGENCY card — pushed from the trip tray. One row per roster child:
/// their allergies / medical-conditions / emergency-instructions note, plus a
/// one-tap CALL to each linked guardian (a `tel:` launch). The data is rich
/// (allergies on `subjects.allergies`; conditions + instructions in the caps
/// bag; guardians via [guardiansForSubjectProvider]) — so this surfaces it all
/// rather than only deep-linking out. A child with no medical note still shows,
/// with their guardians, because "who to call" matters for every kid.
///
/// Offline-first: roster + per-child guardians are Drift watches; nothing
/// awaits the network. No PII is ever logged — phone numbers / allergies stay
/// on-screen only.
class _EmergencyContactsScreen extends ConsumerWidget {
  const _EmergencyContactsScreen({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster =
        ref.watch(subjectsInGroupProvider(groupId)).value ?? const <Subject>[];
    return EdgeScaffold(
      body: SafeArea(
        bottom: false,
        child: roster.isEmpty
            ? const Center(
                child: EmptyState(
                  icon: Icons.emergency_outlined,
                  title: 'No children on this roster',
                  message:
                      'Assign children to this cohort and their allergies and '
                      'emergency contacts will show here.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  const ContentHeader(
                    title: 'Emergency',
                    subtitle:
                        'Allergies, medical notes, and who to call — one tap '
                        'to dial.',
                  ),
                  const SizedBox(height: 8),
                  for (final subj in roster)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EmergencyChildCard(subject: subj),
                    ),
                ],
              ),
      ),
    );
  }
}

/// One child's emergency card — name + photo, their allergy / medical /
/// emergency-instruction lines (only the ones present), then a call button per
/// linked guardian. Guardians read live via [guardiansForSubjectProvider].
class _EmergencyChildCard extends ConsumerWidget {
  const _EmergencyChildCard({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final caps = subject.caps;

    final allergies = subject.allergies?.trim() ?? '';
    final conditions =
        caps.getString(SubjectCaps.medicalConditions)?.trim() ?? '';
    final medications = caps.getString(SubjectCaps.medications)?.trim() ?? '';
    final instructions =
        caps.getString(SubjectCaps.emergencyInstructions)?.trim() ?? '';

    final guardians =
        ref.watch(guardiansForSubjectProvider(subject.id)).value ??
        const <Guardian>[];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PersonAvatar(
                  name: '${subject.firstName} ${subject.lastName}',
                  photoUrl: subject.photoUrl,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${subject.firstName} ${subject.lastName}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            // Medical lines — each only when present. Allergies lead in the
            // error tone (the "watch out" line); the rest are neutral.
            if (allergies.isNotEmpty) ...[
              const SizedBox(height: 12),
              _MedicalLine(
                icon: Icons.warning_amber_rounded,
                label: 'Allergies',
                value: allergies,
                tone: scheme.error,
              ),
            ],
            if (conditions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MedicalLine(
                icon: Icons.medical_information_outlined,
                label: 'Medical',
                value: conditions,
                tone: scheme.onSurfaceVariant,
              ),
            ],
            if (medications.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MedicalLine(
                icon: Icons.medication_outlined,
                label: 'Medications',
                value: medications,
                tone: scheme.onSurfaceVariant,
              ),
            ],
            if (instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MedicalLine(
                icon: Icons.assignment_outlined,
                label: 'If something happens',
                value: instructions,
                tone: scheme.onSurfaceVariant,
              ),
            ],
            const SizedBox(height: 12),
            // Who to call — one row per linked guardian. A guardian with a
            // phone gets a tappable call chip; one without is shown but
            // disabled (so staff still see the contact exists).
            if (guardians.isEmpty)
              Text(
                'No emergency contact on file — add a guardian on the '
                "child's profile.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              for (final g in guardians) _GuardianCallRow(guardian: g),
          ],
        ),
      ),
    );
  }
}

/// A single labelled medical line — icon · label · value. The `tone` colours
/// the icon + label (error for allergies, neutral for the rest); the value
/// rides the full-strength on-surface so it never fails contrast.
class _MedicalLine extends StatelessWidget {
  const _MedicalLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(color: tone, fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One guardian's call row — name + relationship, and a one-tap call button
/// when a phone is on file. The button launches a `tel:` URL externally.
/// Never logs the number.
class _GuardianCallRow extends StatelessWidget {
  const _GuardianCallRow({required this.guardian});

  final Guardian guardian;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final phone = guardian.phone?.trim() ?? '';
    final relationship = guardian.relationship?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardian.name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  relationship.isNotEmpty
                      ? (hasPhone ? '$relationship · $phone' : relationship)
                      : (hasPhone ? phone : 'No phone on file'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (hasPhone)
            FilledButton.tonalIcon(
              onPressed: () => _call(phone),
              icon: const Icon(Icons.call, size: 18),
              label: const Text('Call'),
            )
          else
            // Tap-target-sized disabled placeholder so the row stays aligned
            // and the "no number" state is unmistakable.
            const SizedBox(
              height: 40,
              child: Center(child: Icon(Icons.call_outlined)),
            ),
        ],
      ),
    );
  }

  /// Launch a `tel:` URL externally. Fire-and-forget — we don't block the UI
  /// on the launch, and we NEVER log the number (PII).
  void _call(String phone) {
    unawaited(HapticFeedback.selectionClick());
    final uri = Uri(scheme: 'tel', path: phone);
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }
}

/// A quiet full-width note for a break / closed block — there's nothing to run,
/// so this says so calmly (NOT a dead "Start" hero). An INFO tile (not
/// tappable); the one real action a break still earns (capture a moment) is its
/// own tile beside this.
class _QuietNoteTile extends StatelessWidget {
  const _QuietNoteTile({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      label: text,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              BentoModuleIcon(icon: icon, tint: scheme.surfaceContainerHighest),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The short four-beat "How it runs" captions — hand it over → five-minute game
/// → look together → each picks one. Each beat maps to one of the session's
/// lesson fields (`setup → gameRules → lookingTogether → endRitual`, the same
/// four [_sessionRoutine] reads), so a beat only shows when the session actually
/// has that field — an override that drops "looking together" drops that line
/// rather than showing a phantom step. With NO session resolved (a bare photo
/// block), falls back to the full [routine] text if any, else a sensible
/// default four-beat.
List<String> _runsSteps(PhotoSession? session, List<String> routine) {
  const fallback = [
    'Hand it over',
    'Five-minute game',
    'Look together',
    'Each picks one',
  ];
  if (session == null) {
    return routine.isNotEmpty ? routine : fallback;
  }
  final steps = <String>[];
  if (session.setup.trim().isNotEmpty) steps.add('Hand it over');
  if (session.gameRules.trim().isNotEmpty) steps.add('Five-minute game');
  if (session.lookingTogether.trim().isNotEmpty) steps.add('Look together');
  if (session.endRitual.trim().isNotEmpty) steps.add('Each picks one');
  return steps.isEmpty ? fallback : steps;
}

/// The real arc of a SCRIPTED session for the "How it runs" tile — the
/// content-beat TITLES in order (e.g. "The Hook · The Camera Reveal · The Rules
/// · The Speed Round · …"), so a host reads the actual hour, not the tablet-era
/// four-beat summary. Skips the un-run bookends (`prep` / `doorway` / `after`);
/// keeps every taught beat (hook / reveal / rules / game / cooldown / partner /
/// frame / drawing / vocab / closing). Caps at 8 shown + a final
/// "+N more in the deck" line so the tile stays scannable — the full beat list
/// lives in the presenter the hero opens. Only called when a script resolves;
/// when none does, the caller keeps the existing `_runsSteps` path untouched.
List<String> _scriptRunSteps(SessionScript script) {
  const skip = {BeatKind.prep, BeatKind.doorway, BeatKind.after};
  final titles = [
    for (final beat in script.beats)
      if (!skip.contains(beat.kind)) beat.title.trim(),
  ].where((t) => t.isNotEmpty).toList();
  const cap = 8;
  if (titles.length <= cap) return titles;
  final hidden = titles.length - cap;
  return [...titles.take(cap), '+$hidden more in the deck'];
}

/// The "You'll need" line for a SCRIPTED session — derived from its PREP beat's
/// `keyLines` (the host's "before they arrive" checklist), keeping the lines
/// that read like MATERIALS to stage and dropping the room-/wall-state lines
/// ("Tubes on the table", "the wall has six words now"). A prep keyLine often
/// front-loads "Have ready: …"; we trim that prefix so the result is the bare
/// list. When a session's prep is all room-setup with no clean materials line
/// (e.g. the gallery-day finale), fall back to the photo-session essentials so
/// the tile never reads empty. Only called when a script resolves.
String _scriptNeeds(SessionScript script) {
  // The photo curriculum's through-line: every session hands out tube cameras,
  // journals, crayons. A safe, honest default when prep names nothing else.
  const essentials = 'Tube cameras · journals · crayons';

  final prep = script.beats.where((b) => b.kind == BeatKind.prep).firstOrNull;
  if (prep == null) return essentials;

  // A keyLine is a MATERIALS line when it points at things to bring/stage,
  // rather than describing the room's standing state. Keyword-gated so the
  // tile stays trustworthy across the six prep beats' varied prose.
  bool looksLikeMaterials(String line) {
    final l = line.toLowerCase();
    return l.contains('have ready') ||
        l.contains('have 2') || // "Have 2–3 flashlights"
        l.contains('journals') ||
        l.contains('crayons') ||
        l.contains('flashlight') ||
        l.contains('slips of paper') ||
        l.contains('picture-card') ||
        l.contains('special object');
  }

  final picked = <String>[];
  for (final raw in prep.keyLines) {
    final line = raw.trim();
    if (line.isEmpty || !looksLikeMaterials(line)) continue;
    // Trim a leading "Have ready: " / "Have ready " framing so the line is the
    // bare list; leave everything else (incl. "Have 2–3 flashlights") intact.
    final stripped = line.replaceFirst(
      RegExp(r'^have ready[:,]?\s*', caseSensitive: false),
      '',
    );
    final cleaned = stripped.trim();
    if (cleaned.isNotEmpty) picked.add(cleaned);
  }

  if (picked.isEmpty) return essentials;
  // One line per materials keyLine, joined by the app's mid-dot separator so it
  // reads as a single scannable inventory in the quiet INFO tile.
  return picked.join('  ·  ');
}

/// Build a curriculum session's lesson into the run sheet's numbered routine:
/// one step each for setup → game rules → looking together → end ritual, in
/// that order, using the session's own text trimmed and skipping any field
/// that's empty. This is what REPLACES the (empty) activity routine when the
/// block carries a `curriculumSessionSlug`.
List<String> _sessionRoutine(PhotoSession session) {
  final steps = <String>[];
  for (final field in [
    session.setup,
    session.gameRules,
    session.lookingTogether,
    session.endRitual,
  ]) {
    final trimmed = field.trim();
    if (trimmed.isNotEmpty) steps.add(trimmed);
  }
  return steps;
}
