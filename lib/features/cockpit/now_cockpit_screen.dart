import 'dart:async';

import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/activity_runtime/activity_runners.dart';
import 'package:differentworld/features/cockpit/cockpit_beat.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/features/onboarding/widgets/starter_spine.dart';
import 'package:differentworld/features/recap/recap_setting.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/day_tools_bento.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/slide_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/now` — the clock-driven cockpit (docs/COCKPIT.md → docs/VISION.md, "the
/// app is a clock that knows your kids"). ONE beat at a time, chosen by
/// [cockpitBeatProvider]; the pull-down curiosity bar is the only navigation.
///
/// Slice 1: an [EdgeScaffold] (the chrome + the omnibox bar stay as the
/// always-there escape hatches — keeping the omnibox is on-vision) that FRAMES
/// the current beat by delegating to the surface that already does the work —
/// the active beat reuses [contextLeadProvider] verbatim, so a field trip
/// reveals the vehicle, an activity reveals "Run the session", arrival reveals
/// check-in. Today is untouched until this proves itself (the promotion path,
/// COCKPIT.md fork ⑤).
class NowCockpitScreen extends ConsumerStatefulWidget {
  const NowCockpitScreen({super.key});

  @override
  ConsumerState<NowCockpitScreen> createState() => _NowCockpitScreenState();
}

class _NowCockpitScreenState extends ConsumerState<NowCockpitScreen> {
  bool _curiosityOpen = false;

  @override
  Widget build(BuildContext context) {
    final beat = ref.watch(cockpitBeatProvider);
    final lead = ref.watch(contextLeadProvider);
    // The reveal only makes sense (and only has a non-dead-end destination)
    // when a curriculum world is running — gate the launch on it.
    final hasWorld = ref.watch(currentWorldProvider) != null;
    // Fill the active beat's colour edge-to-edge (behind the now-transparent
    // chrome), so the top band shows the beat's tone instead of the dark
    // Scaffold surface.
    final beatBg = _beatBg(Theme.of(context).colorScheme, beat, lead);
    // Day zero leads with setup, not the clock. StarterSpine self-hides once
    // the steps are done (or dismissed), so this is the whole gate — no
    // separate "is this a new program" flag to drift out of sync.
    final settingUp = ref.watch(starterSpineVisibleProvider);
    return EdgeScaffold(
      background: ColoredBox(color: beatBg),
      body: SafeArea(
        child: Column(
          children: [
            _CuriosityBar(
              key: const ValueKey('cockpit-curiosity'),
              open: _curiosityOpen,
              onToggle: () => setState(() => _curiosityOpen = !_curiosityOpen),
            ),
            // The beat stays the hero — sized to fill the viewport so it owns
            // the first screen. The one-tap tools grid lives just BELOW the
            // fold in the SAME scroll, so it's reachable by a scroll (never the
            // drawer) without ever painting a band: the EdgeScaffold background
            // still bleeds edge-to-edge under everything (it's the Scaffold
            // background, not the body), and the tools ride their own inset
            // panel so they read cleanly over any beat colour.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: Column(
                    children: [
                      // ABOVE the beat, deliberately. For a brand-new program
                      // "what do I do first" IS the beat; the clock stage is
                      // secondary until there's a room and a roster to drive
                      // it. Renders nothing at all once the spine retires.
                      if (settingUp)
                        const StarterSpine(key: ValueKey('cockpit-spine')),
                      SizedBox(
                        // The beat keeps its full-viewport stage; its own
                        // internal scroll (in `_beatFrame`) still handles
                        // 200% text — bounding it here keeps that intact.
                        height: constraints.maxHeight,
                        child: _BeatBody(
                          key: const ValueKey('cockpit-beat-body'),
                          beat: beat,
                          lead: lead,
                          hasWorld: hasWorld,
                        ),
                      ),
                      const _CockpitToolsSection(
                        key: ValueKey('cockpit-tools'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The five Layer-2 "shallows" — pull down to reveal, dive out, dive back.
/// NOT a nav bar: a curiosity affordance most days go untouched. (The exact
/// set is tunable; these are the staff routes that exist today.)
const _curiosityDestinations = <({IconData icon, String label, String route})>[
  (icon: Icons.today_outlined, label: 'Today', route: '/today'),
  (icon: Icons.calendar_month_outlined, label: 'Schedule', route: '/schedule'),
  (icon: Icons.psychology_outlined, label: 'Activities', route: '/tools'),
  (icon: Icons.public_outlined, label: 'Worlds', route: '/program'),
  (icon: Icons.insights_outlined, label: 'Patterns', route: '/insights'),
];

class _CuriosityBar extends StatelessWidget {
  const _CuriosityBar({required this.open, required this.onToggle, super.key});

  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        // The handle — tap to wade in / out. ≥48dp tap target (a11y floor).
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(12),
          child: Semantics(
            button: true,
            label: open ? 'Hide more places' : 'Show more places',
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 5,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        open ? 'Less' : 'More places',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      Icon(
                        open ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final d in _curiosityDestinations)
                        OutlinedButton.icon(
                          onPressed: () {
                            onToggle();
                            context.go(d.route);
                          },
                          icon: Icon(d.icon, size: 18),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The one-tap tools grid below the fold (docs/VISION.md: "everything one tap
/// away… I still hunt down things"). Rides its OWN inset panel — a soft
/// `surface` card with a rounded top — so the grid reads cleanly over whatever
/// colour the beat above paints, WITHOUT becoming a band: the EdgeScaffold
/// background still bleeds edge-to-edge under the chrome (it's the Scaffold's
/// background, not the body). The beat stays the hero; this is reached by a
/// scroll. Excludes Today (you're already here). Bottom padding clears the
/// floating omnibox bar so the last row never hides behind it.
class _CockpitToolsSection extends StatelessWidget {
  const _CockpitToolsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      // Clear the bottom omnibox bar (76dp) plus breathing room so the last
      // row of tools never renders behind the floating glass.
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 96),
      child: const DayToolsBento(excludeRoute: '/'),
    );
  }
}

/// The one beat, full-bleed. The live beats reuse [ContextLead] verbatim; the
/// after-pickup beats ([CockpitBeat.send] / [CockpitBeat.closed]) — where the
/// lead is null — get a cockpit-authored card.
class _BeatBody extends StatelessWidget {
  const _BeatBody({
    required this.beat,
    required this.lead,
    required this.hasWorld,
    super.key,
  });

  final CockpitBeat beat;
  final ContextLead? lead;
  final bool hasWorld;

  @override
  Widget build(BuildContext context) {
    switch (beat) {
      // Slice 2: the program-specific beats get their own inline body instead
      // of the generic lead — morning leads with the verb pick, the closing
      // window with the reveal.
      case CockpitBeat.goodMorning:
        return _MorningCard(lead: lead);
      case CockpitBeat.reveal:
        return const _RevealCard();
      case CockpitBeat.send:
      case CockpitBeat.closed:
        return _AfterPickupCard(beat: beat);
      // The live beats (and prep) reuse the contextual lead verbatim.
      case CockpitBeat.gettingReady:
      case CockpitBeat.now:
      case CockpitBeat.fieldTrip:
      case CockpitBeat.pickup:
        return lead != null
            ? _LeadCard(lead: lead!, beat: beat, hasWorld: hasWorld)
            : _AfterPickupCard(beat: beat);
    }
  }
}

(Color bg, Color fg) _toneColors(ColorScheme s, ContextTone tone) =>
    switch (tone) {
      ContextTone.go => (s.primaryContainer, s.onPrimaryContainer),
      ContextTone.trip => (s.tertiaryContainer, s.onTertiaryContainer),
      ContextTone.pickup => (s.secondaryContainer, s.onSecondaryContainer),
      // Calm/resting uses the base `surface` — the ONE cohesive app background,
      // same as every other screen (active beats keep their moment colour).
      ContextTone.calm => (s.surface, s.onSurface),
    };

/// The active beat's background colour — mirrors what each card paints, so the
/// cockpit can fill it edge-to-edge behind the (transparent) chrome instead of
/// leaving the dark Scaffold surface showing in the top band. Keep in lockstep
/// with the per-card `bg:` values + the `_BeatBody` switch.
Color _beatBg(ColorScheme scheme, CockpitBeat beat, ContextLead? lead) =>
    switch (beat) {
      CockpitBeat.goodMorning => scheme.primaryContainer,
      CockpitBeat.reveal => scheme.primary,
      CockpitBeat.send || CockpitBeat.closed => scheme.surface,
      CockpitBeat.gettingReady ||
      CockpitBeat.now ||
      CockpitBeat.fieldTrip ||
      CockpitBeat.pickup =>
        lead != null ? _toneColors(scheme, lead.tone).$1 : scheme.surface,
    };

/// Full-bleed beat frame: the [bg] colour fills the surface (the emotional
/// arc — colour by the moment), the content is centred + width-capped for
/// wide devices, and the whole thing SCROLLS when text scales up (200%) so the
/// primary action never gets pushed off-screen.
Widget _beatFrame(
  BuildContext context, {
  required Color bg,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    color: bg,
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                child: IntrinsicHeight(child: child),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _LeadCard extends ConsumerWidget {
  const _LeadCard({
    required this.lead,
    required this.beat,
    required this.hasWorld,
  });

  final ContextLead lead;
  final CockpitBeat beat;
  final bool hasWorld;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final (bg, fg) = _toneColors(theme.colorScheme, lead.tone);
    // The reveal is a manual beat (COCKPIT.md fork ③): surface it as a quiet
    // secondary launch during the live program / pickup window — but ONLY when
    // a curriculum world is actually running, or /play-today is a dead end.
    final showReveal =
        hasWorld && (beat == CockpitBeat.now || beat == CockpitBeat.pickup);
    // The "advance" cue (docs/WORKFLOWS.md seam 4 "the cockpit shows now but
    // never next"): on the LIVE program beat, surface the cohort's NEXT planned
    // block so the cockpit hands the teacher what's coming instead of just
    // naming now. Resolve the live cohort the SAME way cockpitBeatProvider does
    // — honor the context-pill room override, else "live across my rooms" — so
    // "next" is the next block for whatever room is live now. Only on `now`
    // (pickup/trip have their own forward chain); self-hides when nothing's
    // left on the day or no room is live.
    final override = ref.watch(contextRoomOverrideProvider);
    String? liveGroupId;
    if (beat == CockpitBeat.now) {
      // A pinned room IS the cohort; otherwise take whichever of my rooms is
      // live now (most-recently-started, same as the beat).
      liveGroupId = override ?? ref.watch(liveBlockProvider)?.groupId;
    }
    final next = liveGroupId == null
        ? null
        : ref.watch(nextScheduledBlockProvider(liveGroupId));
    // The live beat IS a slide (docs/VISION.md 2026-06-19): info + actions in
    // one block. Render-identical to the hand-rolled card it replaces; the
    // shape is now the shared SlideBlock primitive every other beat reuses.
    // The "what's next" line rides the slide's `footer` slot (NOT an outer
    // Column — that breaks the slide's Spacers under IntrinsicHeight).
    return _beatFrame(
      context,
      bg: bg,
      child: SlideBlock(
        foreground: fg,
        accentBackground: fg,
        accentForeground: bg,
        icon: lead.icon,
        eyebrow: lead.eyebrow,
        title: lead.title,
        body: Text(lead.line),
        primary: SlideAction(
          label: lead.primary.label,
          icon: lead.primary.icon,
          onPressed: () => context.push(lead.primary.route),
        ),
        actions: [
          for (final move in lead.more)
            SlideAction(
              label: move.label,
              icon: move.icon,
              onPressed: () => context.push(move.route),
            ),
        ],
        // The slide coordinates the room: cast the live world to the TV while
        // the phone stays the remote (docs/VISION.md 2026-06-19, dream
        // #14/#18). Only when a world is running — otherwise there's nothing
        // to present.
        onCast: hasWorld
            ? () => unawaited(
                showCastToRoom(
                  context,
                  mirrorRoute: '/journey',
                  mirrorSubtitle:
                      'Open the room’s world here, then mirror it to the TV — '
                      'run the room from your phone.',
                ),
              )
            : null,
        tertiary: showReveal
            ? SlideAction(
                label: 'Start the reveal',
                icon: Icons.auto_awesome_outlined,
                onPressed: () => context.push('/play-today'),
              )
            : null,
        footer: next == null
            ? null
            : _NextBlockLine(next: next, foreground: fg),
      ),
    );
  }
}

/// The quiet "what's next" line under the live beat's actions — the cockpit's
/// ADVANCE cue (docs/WORKFLOWS.md seam 4). Reads as one subtle row, in the
/// beat's own foreground so it stays on the calm surface (never a loud second
/// card). A tap LAUNCHES the next block's run the exact way the schedule's
/// "Run" button does: the activity's chosen runner if it names one, else the
/// generic `/arc` teaching arc.
class _NextBlockLine extends StatelessWidget {
  const _NextBlockLine({required this.next, required this.foreground});

  final NextBlock next;
  final Color foreground;

  void _launch(BuildContext context) {
    // Mirror block_run_sheet_screen._start exactly — the SAME runner-slug /
    // teaching-arc launch the agenda tile's "Run" button uses.
    final runner = runnerForSlug(next.runnerSlug);
    if (runner != null) {
      final dest = runner.takesPrompt
          ? Uri(
              path: runner.route,
              queryParameters: {'prompt': next.runTopic},
            ).toString()
          : runner.route;
      unawaited(context.push(dest));
    } else {
      unawaited(context.push('/arc', extra: next.runTopic));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = foreground;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _launch(context),
          borderRadius: BorderRadius.circular(12),
          child: Semantics(
            button: true,
            label:
                'Next: ${next.title} at ${timeOfDay(next.startAt)}. '
                'Tap to start it.',
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: fg.withValues(alpha: 0.25)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.skip_next_outlined,
                    size: 18,
                    color: fg.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fg.withValues(alpha: 0.9),
                        ),
                        children: [
                          TextSpan(
                            text: 'Next · ${timeOfDay(next.startAt)}  ',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(text: next.title),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: fg.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AfterPickupCard extends ConsumerWidget {
  const _AfterPickupCard({required this.beat});

  final CockpitBeat beat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSend = beat == CockpitBeat.send;
    // The send beat has two ways home that didn't converge (docs/WORKFLOWS.md
    // "the closing chain"): the action-words note AND the daily recap. When
    // recap is on, offer it as a quiet second link beside Send home — same
    // discovery gate the omnibox + pickup board use.
    final recapOn = ref.watch(recapEnabledProvider).value ?? false;
    return _beatFrame(
      context,
      bg: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSend
                ? Icons.mark_email_unread_outlined
                : Icons.nightlight_outlined,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
          const Spacer(),
          Text(
            isSend ? 'After pickup' : "Day's done",
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isSend ? 'Send today home' : 'All done for today',
            style: theme.textTheme.displaySmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSend
                ? "Each child's note is ready — copy it and send."
                : 'Nothing left on the board. See you tomorrow.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 16),
          if (isSend) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/action-words/send'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Send home'),
              ),
            ),
            if (recapOn) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push('/recap'),
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onSurfaceVariant,
                  ),
                  icon: const Icon(Icons.auto_stories_outlined, size: 18),
                  label: const Text('Or send today’s recap'),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Morning beat — greeting + the journey position, leading with the verb pick
/// (the 9:10 signature move, docs/VISION.md) and the arrival lead's check-in
/// alongside. Warm "go" tone — the room waking up.
class _MorningCard extends ConsumerWidget {
  const _MorningCard({required this.lead});

  final ContextLead? lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final position = ref.watch(seasonPositionProvider);
    final world = position?.world;
    final bg = scheme.primaryContainer;
    final fg = scheme.onPrimaryContainer;
    final lead = this.lead;
    // The morning beat's one cheap "done → next" signal (docs/WORKFLOWS.md
    // seam 4): if the room has already picked its words today, don't keep
    // telling the teacher to pick — acknowledge it's set and point the primary
    // FORWARD to the words that are in. Pure derivation off the existing picks
    // stream; no completion-state table.
    final picked = ref.watch(todaysRevealItemsProvider).length;
    final hasPicked = picked > 0;
    final worldLine = world != null
        ? '${world.emoji}  ${world.name} · week ${position!.week}'
        : "Check the room in, then pick today's words.";
    return _beatFrame(
      context,
      bg: bg,
      child: SlideBlock(
        foreground: fg,
        accentBackground: fg,
        accentForeground: bg,
        icon: Icons.wb_sunny_outlined,
        eyebrow: 'Good morning',
        title: world != null ? 'Day ${position!.day}' : 'A new day',
        body: Text(
          hasPicked
              ? '$picked ${picked == 1 ? 'child has' : 'children have'} '
                    'picked their words — the room is set.'
              : worldLine,
        ),
        primary: hasPicked
            ? SlideAction(
                label: "See today's words",
                icon: Icons.auto_awesome_outlined,
                onPressed: () => context.push('/action-words'),
              )
            : SlideAction(
                label: "Pick today's verbs",
                icon: Icons.auto_awesome_outlined,
                onPressed: () => context.push('/action-words'),
              ),
        actions: lead == null
            ? const []
            : [
                SlideAction(
                  label: lead.primary.label,
                  icon: lead.primary.icon,
                  onPressed: () => context.push(lead.primary.route),
                ),
                for (final move in lead.more)
                  SlideAction(
                    label: move.label,
                    icon: move.icon,
                    onPressed: () => context.push(move.route),
                  ),
              ],
      ),
    );
  }
}

/// The closing-window reveal launch. Themed (the dark immersive stage itself
/// lives at /play-today, the destination); a bold primary fill marks it as THE
/// moment of the day, distinct from the utilitarian "now".
class _RevealCard extends ConsumerWidget {
  const _RevealCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = scheme.primary;
    final fg = scheme.onPrimary;
    return _beatFrame(
      context,
      bg: bg,
      child: SlideBlock(
        foreground: fg,
        accentBackground: fg,
        accentForeground: bg,
        icon: Icons.auto_awesome_outlined,
        eyebrow: 'The closing',
        title: 'Reveal the day',
        body: const Text(
          'Gather the room — each child becomes who they were today.',
        ),
        primary: SlideAction(
          label: 'Start the reveal',
          icon: Icons.play_circle_outline,
          onPressed: () => context.push('/play-today'),
        ),
        // Make the closing SEQUENCE legible (docs/WORKFLOWS.md "the closing
        // chain": reveal → pickup → send) — a quiet forward link to the
        // dismissal board sits next to the reveal, so the day reads as a chain,
        // not three isolated surfaces. Small link, not a new engine.
        actions: [
          SlideAction(
            label: 'Then: pickup',
            icon: Icons.directions_walk,
            onPressed: () => context.push('/pickup'),
          ),
        ],
        // Never cage: the reveal auto-appears near pickup, but a teacher
        // mid-activity can stay in program — one tap back.
        tertiary: SlideAction(
          label: 'Not yet — stay in program',
          icon: Icons.keyboard_return,
          onPressed: () => ref.read(revealDismissedProvider.notifier).dismiss(),
        ),
      ),
    );
  }
}
