import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/action_words/block_actions.dart';
import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Arguments for the `/journey/present` + `/play-today/present` routes — the
/// immersive `BeatPresenter` is fed entirely from this, carried over go_router
/// `extra`. Mirrors the existing `extra`-passed arg records (BlockEditArgs,
/// PresentDeckArgs) so a missing-extra deep link can fall back to the base
/// route.
@immutable
class DeckPresentArgs {
  const DeckPresentArgs({
    required this.beats,
    required this.accent,
    this.emoji = '',
    this.initialBeat = 0,
    this.onBeatChanged,
    this.onFinished,
  });

  /// The ordered run to present.
  final List<DayBeat> beats;

  /// The deck's room colour (journey purple, today's world colour).
  final Color accent;

  /// Optional hero glyph for `open` beats (the world emoji).
  final String emoji;

  /// Which beat to open on — the tapped tile's index.
  final int initialBeat;

  /// Threaded through to the presenter (the day run remembers where the
  /// teacher landed; the journey leaves it null).
  final ValueChanged<int>? onBeatChanged;

  /// The "what's next" handoff builder, threaded to the presenter so the
  /// deck-overview path of `/play-today` gets the same end-of-run handoff as
  /// the direct path. The journey leaves it null (just pops, unchanged). See
  /// `BeatPresenter.onFinished`.
  final Widget Function(BuildContext context, VoidCallback dismiss)? onFinished;
}

/// A toggle-gated, NON-immersive overview of a BeatPresenter deck (the journey
/// or the day run): the run laid out as a tappable grid of beat tiles instead
/// of dropping straight into the full-screen slideshow. Tapping a tile presents
/// the deck starting AT that beat; the "Present from the start" button opens at
/// beat 0.
///
/// Renders as a normal scrollable body inside an `EdgeScaffold` (the caller
/// wraps it), so the floating chrome clears automatically via the
/// [ContentHeader] / `MediaQuery.padding.top` reservation — no per-screen
/// `topChromeHeight` math. Off by default; see `presentDeckOverviewProvider`.
class DeckOverview extends StatelessWidget {
  const DeckOverview({
    required this.beats,
    required this.accent,
    required this.title,
    required this.onPresent,
    this.emoji = '',
    this.subtitle,
    this.arc,
    this.actionsForBeat,
    super.key,
  });

  /// The ordered run, one tile per beat.
  final List<DayBeat> beats;

  /// The deck accent — the tile fill when a beat carries no per-beat colour.
  final Color accent;

  /// Hero glyph used for `open` beats that don't carry their own emoji.
  final String emoji;

  /// Page title ("The journey" / today's world name).
  final String title;

  /// Optional supporting line ("10 worlds · tap any to start there").
  final String? subtitle;

  /// Optional widget shown between the header and the grid — the run-day arc
  /// strip (the day's energy curve). Null for decks with no arc.
  final Widget? arc;

  /// Present the deck starting at `beatIndex`. The caller pushes the immersive
  /// present route with a [DeckPresentArgs] built from the SAME beats + accent.
  final void Function(int beatIndex) onPresent;

  /// Optional per-beat "use right now" launchers — the app features relevant to
  /// that block, rendered as a host-only tray on the (never-mirrored) card so
  /// the slide is a launchpad, not just a teleprompter (docs/VISION.md). Null
  /// for decks with no block context (the journey, play-today's world run).
  final List<BeatAction> Function(int beatIndex)? actionsForBeat;

  @override
  Widget build(BuildContext context) {
    // Two columns on a phone; widen on tablet / desktop so the grid spreads
    // (the bento-grid sensibility) rather than stretching two columns wide.
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1000
        ? 4
        : width >= 700
        ? 3
        : 2;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverToBoxAdapter(
            child: ContentHeader(title: title, subtitle: subtitle),
          ),
        ),
        if (arc != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: arc,
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: Insets.md,
              crossAxisSpacing: Insets.md,
              // Slightly taller than square — room for the emoji + a two-line
              // headline + the eyebrow. Taller again when each tile also carries
              // its action tray (48dp chips, up to two rows) without crowding.
              childAspectRatio: actionsForBeat != null ? 0.62 : 0.92,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _BeatTile(
                beat: beats[i],
                accent: accent,
                emoji: emoji,
                onTap: () => onPresent(i),
                actions: actionsForBeat?.call(i),
              ),
              childCount: beats.length,
            ),
          ),
        ),
        // The "from the start" CTA, full-width below the grid. Padding clears
        // the bottom omnibox bar (the shell reserves 76dp for the body, but
        // this lives in a scroll view so a little extra keeps it comfortable).
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                // Don't let the CTA stretch the full desktop width.
                constraints: const BoxConstraints(maxWidth: 480),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: beats.isEmpty ? null : () => onPresent(0),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Present from the start'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One beat as a tappable tile — emoji glyph, the headline, and the eyebrow
/// label, on a low-alpha tint of the beat's (or deck's) accent. Content-driven
/// fill, so the text colour is picked for contrast via [AppColors.onAccent].
class _BeatTile extends StatelessWidget {
  const _BeatTile({
    required this.beat,
    required this.accent,
    required this.emoji,
    required this.onTap,
    this.actions,
  });

  final DayBeat beat;
  final Color accent;
  final String emoji;
  final VoidCallback onTap;

  /// The block's "use right now" launchers, rendered as a tray below the
  /// headline. Null on decks with no block context (the tile is present-only).
  final List<BeatAction>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The beat's own world colour if it has one, else the deck accent.
    final tint = beat.color ?? accent;
    // The fill is the accent at low alpha over the surface — so the tile reads
    // tinted but stays calm. The foreground reads against that *blended* fill,
    // which is close to the surface, so onSurface ink is correct; we keep the
    // accent itself only for the small eyebrow + glyph cue.
    final fill = Color.alphaBlend(
      tint.withValues(alpha: 0.12),
      theme.colorScheme.surface,
    );
    final onFill = AppColors.onAccent(fill);
    // The eyebrow is the quiet label — the SAME contrast-correct ink as the
    // headline (chosen for the blended FILL it actually sits on, NOT the raw
    // accent: onAccent(tint) went white-on-light for a dark world colour),
    // just muted so it reads as secondary under the headline.
    final eyebrowColor = onFill.withValues(alpha: 0.72);

    final glyph = beat.emoji.isNotEmpty
        ? beat.emoji
        : (beat.kind == DayBeatKind.open && emoji.isNotEmpty
              ? emoji
              : _fallbackGlyph(beat.kind));
    // The headline read on the tile — the big line, or the label when a beat
    // (a verbs/activity list) carries no headline.
    final headline = beat.big.isNotEmpty ? beat.big : beat.label;
    final hasTray = actions != null && actions!.isNotEmpty;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(Radii.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The card body — tap to present this slide.
          Expanded(
            key: const ValueKey('tile-body'),
            child: Semantics(
              button: true,
              label: 'Present from ${headline.isEmpty ? beat.label : headline}',
              child: InkWell(
                onTap: () {
                  unawaited(HapticFeedback.selectionClick());
                  onTap();
                },
                child: Padding(
                  padding: EdgeInsets.fromLTRB(14, 14, 14, hasTray ? 6 : 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(glyph, style: const TextStyle(fontSize: 34)),
                      const SizedBox(height: 10),
                      // Eyebrow — small, tracked, uppercase (the brand's label
                      // voice).
                      if (beat.label.isNotEmpty)
                        Text(
                          beat.label.toUpperCase(),
                          semanticsLabel: beat.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: eyebrowColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          headline,
                          maxLines: hasTray ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: onFill,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // The "use right now" tray — the block's launchers, host-only.
          if (hasTray)
            Padding(
              key: const ValueKey('tile-tray'),
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: _ActionTray(actions: actions!, onFill: onFill),
            ),
        ],
      ),
    );
  }

  /// A sensible glyph for a beat that carries no emoji of its own — so every
  /// tile shows SOMETHING recognisable, not a blank.
  static String _fallbackGlyph(DayBeatKind kind) => switch (kind) {
    DayBeatKind.open => '🌍',
    DayBeatKind.question => '❓',
    DayBeatKind.verbs => '✨',
    DayBeatKind.rule => '📜',
    DayBeatKind.watch => '👀',
    DayBeatKind.play => '▶️',
    DayBeatKind.name => '🔤',
    DayBeatKind.bridge => '🌉',
    DayBeatKind.ask => '💬',
    DayBeatKind.activity => '🎯',
    DayBeatKind.photo => '📷',
    DayBeatKind.close => '🌟',
  };
}

/// The block's "use right now" launchers as a compact tray of chips. Sits on the
/// tinted card, so its ink derives from the card's contrast-correct [onFill]
/// (not a hardcoded colour) and stays readable on any world hue. Each chip taps
/// independently of the card's present-tap.
class _ActionTray extends StatelessWidget {
  const _ActionTray({required this.actions, required this.onFill});

  final List<BeatAction> actions;
  final Color onFill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = onFill.withValues(alpha: 0.22);
    final ink = onFill.withValues(alpha: 0.92);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final a in actions)
          Tooltip(
            message: a.label,
            child: Semantics(
              button: true,
              label: a.label,
              child: Material(
                color: Colors.transparent,
                shape: StadiumBorder(side: BorderSide(color: border)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: a.onTap,
                  child: ConstrainedBox(
                    // ≥48dp tap target — a raw InkWell gets no minimum on its
                    // own (only themed buttons do).
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(a.icon, size: 16, color: ink),
                          const SizedBox(width: 5),
                          Text(
                            a.label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
