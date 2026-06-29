import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
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
              // headline + the eyebrow without crowding.
              childAspectRatio: 0.92,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _BeatTile(
                beat: beats[i],
                accent: accent,
                emoji: emoji,
                onTap: () => onPresent(i),
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
  });

  final DayBeat beat;
  final Color accent;
  final String emoji;
  final VoidCallback onTap;

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

    return Semantics(
      button: true,
      label: 'Present from ${headline.isEmpty ? beat.label : headline}',
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(glyph, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 10),
                // Eyebrow — small, tracked, uppercase (the brand's label voice).
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
                    maxLines: 3,
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
