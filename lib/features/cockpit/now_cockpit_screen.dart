import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/cockpit/cockpit_beat.dart';
import 'package:differentworld/features/today/context_lead.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
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
    return EdgeScaffold(
      body: SafeArea(
        child: Column(
          children: [
            _CuriosityBar(
              key: const ValueKey('cockpit-curiosity'),
              open: _curiosityOpen,
              onToggle: () => setState(() => _curiosityOpen = !_curiosityOpen),
            ),
            Expanded(
              child: _BeatBody(
                key: const ValueKey('cockpit-beat-body'),
                beat: beat,
                lead: lead,
                hasWorld: hasWorld,
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
  (icon: Icons.today_outlined, label: 'Today', route: '/'),
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
    if (lead != null) {
      return _LeadCard(lead: lead!, beat: beat, hasWorld: hasWorld);
    }
    return _AfterPickupCard(beat: beat);
  }
}

(Color bg, Color fg) _toneColors(ColorScheme s, ContextTone tone) =>
    switch (tone) {
      ContextTone.go => (s.primaryContainer, s.onPrimaryContainer),
      ContextTone.trip => (s.tertiaryContainer, s.onTertiaryContainer),
      ContextTone.pickup => (s.secondaryContainer, s.onSecondaryContainer),
      ContextTone.calm => (s.surfaceContainerHighest, s.onSurface),
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

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.lead,
    required this.beat,
    required this.hasWorld,
  });

  final ContextLead lead;
  final CockpitBeat beat;
  final bool hasWorld;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, fg) = _toneColors(theme.colorScheme, lead.tone);
    // The reveal is a manual beat (COCKPIT.md fork ③): surface it as a quiet
    // secondary launch during the live program / pickup window — but ONLY when
    // a curriculum world is actually running, or /play-today is a dead end.
    final showReveal =
        hasWorld && (beat == CockpitBeat.now || beat == CockpitBeat.pickup);
    return _beatFrame(
      context,
      bg: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(lead.icon, size: 40, color: fg),
          const Spacer(),
          Text(
            lead.eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lead.title,
            style: theme.textTheme.displaySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lead.line,
            style: theme.textTheme.titleMedium?.copyWith(
              color: fg.withValues(alpha: 0.9),
            ),
          ),
          const Spacer(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.push(lead.primary.route),
              style: FilledButton.styleFrom(
                backgroundColor: fg,
                foregroundColor: bg,
                padding: const EdgeInsets.symmetric(vertical: 18),
                textStyle: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              icon: Icon(lead.primary.icon),
              label: Text(lead.primary.label),
            ),
          ),
          if (lead.more.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final move in lead.more)
                  OutlinedButton.icon(
                    onPressed: () => context.push(move.route),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: fg,
                      side: BorderSide(color: fg.withValues(alpha: 0.4)),
                    ),
                    icon: Icon(move.icon, size: 18),
                    label: Text(move.label),
                  ),
              ],
            ),
          ],
          if (showReveal) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.push('/play-today'),
                style: TextButton.styleFrom(foregroundColor: fg),
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('Start the reveal'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AfterPickupCard extends StatelessWidget {
  const _AfterPickupCard({required this.beat});

  final CockpitBeat beat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSend = beat == CockpitBeat.send;
    return _beatFrame(
      context,
      bg: scheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSend ? Icons.mark_email_unread_outlined : Icons.nightlight_outlined,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
          const Spacer(),
          Text(
            isSend ? 'AFTER PICKUP' : "DAY'S DONE",
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
                ? 'Open messages to reach each family.'
                : 'Nothing left on the board. See you tomorrow.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 16),
          if (isSend)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push('/messages'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.send_outlined),
                label: const Text('Open messages'),
              ),
            ),
        ],
      ),
    );
  }
}
