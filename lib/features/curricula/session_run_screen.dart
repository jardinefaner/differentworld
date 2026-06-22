// The SESSION RUN PRESENTER — a host runs a scripted curriculum session
// beat by beat, each beat one calm bento slide (the approved mockup). Unlike
// the immersive cast surface (BeatPresenter), this is the phone-first, in-app
// presenter the staffer drives from their hand: chrome stays (back + title +
// Cast), the omnibox spine stays, and the host controls the pace — the per-beat
// countdown is opt-in and never auto-advances.
//
// Content comes from `scriptForSession(slug)` (session_script.dart +
// photo_s1_script.dart) — a const, offline-forever editorial script. A slug
// with no script renders a calm EmptyState; the screen never errors.
//
// Top to bottom (per slide): the current beat as a card (eyebrow time · kind →
// Fraunces title → a tinted "Say this" card of the keyLines → an italic stage
// cue → a call-and-response chip → tap-to-expand the FULL script) → an advance
// bar (pause/timer + a big "Next · {next beat}") → the SEQUENCE timeline (all
// beats as a compact tappable list, the current one highlighted).

import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/curricula/photo_s1_script.dart';
import 'package:differentworld/features/curricula/session_script.dart';
import 'package:differentworld/features/live_session/cast_to_room.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/session/run?slug=<slug>&block=<blockId?>` — the beat-by-beat presenter for
/// one scripted curriculum session. `slug` resolves the script; `block` (when a
/// run-sheet launched it) scopes the game-beat "Start shooting" handoff to a
/// schedule block so each child's shot is tagged with it.
class SessionRunScreen extends ConsumerStatefulWidget {
  const SessionRunScreen({required this.slug, this.blockId, super.key});

  final String slug;

  /// The schedule block this run belongs to, when launched from a run sheet.
  /// Threaded onto the game-beat photo-turns push so shots tag to the block;
  /// null when the session is run standalone (omnibox / deep link).
  final String? blockId;

  @override
  ConsumerState<SessionRunScreen> createState() => _SessionRunScreenState();
}

class _SessionRunScreenState extends ConsumerState<SessionRunScreen> {
  /// The current beat. The single source of truth; the slide + timeline both
  /// read it, a swipe or the Next button or a timeline tap all move it.
  int _index = 0;

  /// Direction of the last move (+1 forward / -1 back) — drives the slide's
  /// enter/exit transition so a forward step slides left, a back step right.
  int _dir = 1;

  /// Whether the current beat's full script is expanded (the "tap to expand").
  /// Reset to false whenever the beat changes so a new beat opens calm.
  bool _expanded = false;

  // The per-beat countdown (the Timer primitive) — host-controlled, NOT
  // auto-advancing. null = no countdown running; otherwise seconds remaining.
  Timer? _ticker;
  int? _remaining;
  bool _paused = false;

  @override
  void dispose() {
    // Guard the Timer in dispose (a fast back-pop must not leave it ticking).
    _ticker?.cancel();
    super.dispose();
  }

  // ── Navigation between beats ──────────────────────────────────────────

  /// Move to beat [i]. Collapses the expanded script + clears any running
  /// countdown so a new beat starts on its own calm view with a fresh (un-
  /// started) timer. Clamped; a no-op if already there.
  void _goTo(int i, int count) {
    if (!mounted) return;
    final next = i.clamp(0, count - 1);
    if (next == _index) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _dir = next > _index ? 1 : -1;
      _index = next;
      _expanded = false;
      _clearTimerState();
    });
  }

  // ── The per-beat countdown ────────────────────────────────────────────

  void _clearTimerState() {
    _ticker?.cancel();
    _ticker = null;
    _remaining = null;
    _paused = false;
  }

  /// Start (or restart) the countdown for the current beat from its
  /// durationMinutes. Host taps to start — never automatic.
  void _startCountdown(int minutes) {
    if (minutes <= 0) return;
    unawaited(HapticFeedback.selectionClick());
    _ticker?.cancel();
    setState(() {
      _remaining = minutes * 60;
      _paused = false;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  void _tick(Timer t) {
    if (!mounted) {
      t.cancel();
      return;
    }
    if (_paused) return;
    final r = _remaining;
    if (r == null || r <= 0) {
      t.cancel();
      return;
    }
    setState(() => _remaining = r - 1);
    if (_remaining == 0) {
      t.cancel();
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  void _togglePause() {
    if (_remaining == null) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _paused = !_paused);
  }

  void _stopCountdown() {
    unawaited(HapticFeedback.selectionClick());
    setState(_clearTimerState);
  }

  // ── Game handoff ──────────────────────────────────────────────────────

  /// The game-beat "Start shooting" handoff → the per-child timed photo turns,
  /// scoped to the block (so each shot tags to it) and seeded with the game's
  /// mission + shooting minutes. `block=` is included only when a block id was
  /// passed in (a standalone run leaves the turns roster program-wide).
  void _startShooting(SessionBeat beat) {
    unawaited(HapticFeedback.selectionClick());
    final game = beat.game;
    final blockId = widget.blockId;
    final gamePrompt = game?.prompt?.trim();
    final prompt = (gamePrompt != null && gamePrompt.isNotEmpty)
        ? gamePrompt
        : beat.title.trim();
    final minutes = game?.minutes ?? beat.durationMinutes;
    final dest = Uri(
      path: '/activity/photo-turns',
      queryParameters: {
        'block': ?blockId,
        'prompt': prompt,
        if (minutes != null) 'minutes': '$minutes',
      },
    ).toString();
    unawaited(context.push(dest));
  }

  void _cast(BuildContext context) {
    // Reuse the one "Cast to the room" chooser — mirror this presenter onto a
    // TV (the host keeps driving from the phone), or pair a second screen.
    final blockId = widget.blockId;
    unawaited(
      showCastToRoom(
        context,
        mirrorRoute: Uri(
          path: '/session/run',
          queryParameters: {
            'slug': widget.slug,
            'block': ?blockId,
          },
        ).toString(),
        mirrorLabel: 'Show this session on the screen',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final script = scriptForSession(widget.slug);

    // No script for this slug → a calm empty state, never an error (the script
    // is const, so this is a genuine "not authored yet", not a load failure).
    if (script == null || script.beats.isEmpty) {
      return EdgeScaffold(
        backFallbackRoute: '/settings/curricula/photo',
        body: SafeArea(
          bottom: false,
          child: EmptyState(
            icon: Icons.menu_book_outlined,
            title: "This session isn't scripted yet.",
            message:
                'The beat-by-beat run sheet is only written for some sessions '
                'so far. Open the curriculum to read the session plan.',
            action: FilledButton(
              onPressed: () => context.go('/settings/curricula/photo'),
              child: const Text('Open the curriculum'),
            ),
          ),
        ),
      );
    }

    final beats = script.beats;
    final count = beats.length;
    final safeIndex = _index.clamp(0, count - 1);
    final current = beats[safeIndex];
    final next = safeIndex < count - 1 ? beats[safeIndex + 1] : null;

    return EdgeScaffold(
      backFallbackRoute: '/settings/curricula/photo',
      actions: [
        IconButton(
          tooltip: 'Cast to the room',
          icon: const Icon(Icons.cast),
          onPressed: () => _cast(context),
        ),
      ],
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          // Bottom pad clears the omnibox bar; capped + centered so the slide
          // doesn't stretch on a desktop window.
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Breakpoints.splitMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The session identity — Fraunces title, eyebrow with the
                  // session number, position through the run. Cast lives in the
                  // pill; back is the chrome back.
                  ContentHeader(
                    title: script.title,
                    subtitle:
                        'Through my eyes · S${script.sessionNumber}  ·  '
                        'beat ${safeIndex + 1} of $count',
                  ),
                  // The current beat — one bento slide. Swipe left/right to
                  // advance (the page-turn interaction) AND the Next button
                  // below; the slide animates in the swipe direction. The whole
                  // column (slide + bar + timeline) lives in the one outer
                  // scroll, so the slide itself wraps its content height.
                  _SwipeBeat(
                    onSwipe: (delta) => _goTo(safeIndex + delta, count),
                    child: _BeatSlide(
                      // A direction-carrying key by index: AnimatedSwitcher
                      // cross-fades/slides between beats (and the keyed child
                      // can't poison a sibling's Element when it changes); the
                      // direction tells the transition which way to slide in.
                      key: _DirectionedKey('beat-slide-$safeIndex', _dir),
                      beat: current,
                      expanded: _expanded,
                      remaining: _remaining,
                      paused: _paused,
                      onToggleExpand: () =>
                          setState(() => _expanded = !_expanded),
                      onStartShooting: () => _startShooting(current),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // The advance bar — timer controls + the big Next button.
                  _AdvanceBar(
                    current: current,
                    next: next,
                    remaining: _remaining,
                    paused: _paused,
                    onStartCountdown: () {
                      final mins = current.durationMinutes;
                      if (mins != null) _startCountdown(mins);
                    },
                    onTogglePause: _togglePause,
                    onStopCountdown: _stopCountdown,
                    onNext: next == null
                        ? null
                        : () => _goTo(safeIndex + 1, count),
                  ),
                  const SizedBox(height: 24),
                  // The SEQUENCE — every beat as a compact tappable timeline,
                  // the current one highlighted. Tap to jump.
                  _SequenceTimeline(
                    beats: beats,
                    current: safeIndex,
                    onJump: (i) => _goTo(i, count),
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

// ─────────────────────────────────────────────────────────────────────────
// Kind → accent
// ─────────────────────────────────────────────────────────────────────────

/// One beat kind's accent — a content-driven categorical colour (NOT a theme
/// role; these are deliberately varied for at-a-glance recognition, like the
/// activity palette). Text/icons ON this fill pick contrast via
/// [AppColors.onAccent]; small dots/borders use it raw.
///
/// Mapping (per the brief): hook/reveal/rules/closing → warm amber;
/// game → blue; cooldown → teal; partner → blue; frame → purple;
/// drawing → pink; vocab → gold; prep/doorway/after → neutral brown.
Color _accentForKind(BeatKind kind) => switch (kind) {
  BeatKind.hook ||
  BeatKind.reveal ||
  BeatKind.rules ||
  BeatKind.closing => ActivityPalette.amber,
  BeatKind.game => ActivityPalette.blue,
  BeatKind.cooldown => ActivityPalette.teal,
  BeatKind.partner => ActivityPalette.lightBlue,
  BeatKind.frame => ActivityPalette.purple,
  BeatKind.drawing => ActivityPalette.pink,
  BeatKind.vocab => ActivityPalette.yellow,
  BeatKind.prep || BeatKind.doorway || BeatKind.after => ActivityPalette.brown,
};

/// Short kind label for the eyebrow + timeline (lowercase, the calm voice).
String _kindLabel(BeatKind kind) => switch (kind) {
  BeatKind.prep => 'prep',
  BeatKind.hook => 'the hook',
  BeatKind.reveal => 'the reveal',
  BeatKind.rules => 'the rules',
  BeatKind.game => 'game',
  BeatKind.cooldown => 'cool down',
  BeatKind.partner => 'partner',
  BeatKind.frame => 'frame game',
  BeatKind.drawing => 'drawing',
  BeatKind.vocab => 'vocabulary',
  BeatKind.closing => 'closing',
  BeatKind.doorway => 'doorway',
  BeatKind.after => 'after',
};

/// The leading glyph for a beat kind — decorative; the label carries meaning.
IconData _kindIcon(BeatKind kind) => switch (kind) {
  BeatKind.prep => Icons.inventory_2_outlined,
  BeatKind.hook => Icons.visibility_outlined,
  BeatKind.reveal => Icons.camera_outlined,
  BeatKind.rules => Icons.rule_outlined,
  BeatKind.game => Icons.sports_esports_outlined,
  BeatKind.cooldown => Icons.spa_outlined,
  BeatKind.partner => Icons.handshake_outlined,
  BeatKind.frame => Icons.crop_outlined,
  BeatKind.drawing => Icons.draw_outlined,
  BeatKind.vocab => Icons.abc_outlined,
  BeatKind.closing => Icons.flag_outlined,
  BeatKind.doorway => Icons.door_front_door_outlined,
  BeatKind.after => Icons.bedtime_outlined,
};

/// `m:ss`, tabular. Self-contained so this screen doesn't couple to another
/// feature's formatter.
String _mmss(int seconds) {
  final m = seconds ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

// ─────────────────────────────────────────────────────────────────────────
// The swipe wrapper
// ─────────────────────────────────────────────────────────────────────────

/// Wraps the current beat slide with the page-turn interaction: a horizontal
/// fling left → next, right → previous (the swipe the mockup asks for), plus an
/// `AnimatedSwitcher` so the new slide slides in from the swipe direction. The
/// child wraps its own content height, so the whole presenter (slide + advance
/// bar + timeline) flows in the one outer vertical scroll — no fragile
/// fixed-height/measured PageView fighting the scroll.
class _SwipeBeat extends StatelessWidget {
  const _SwipeBeat({required this.onSwipe, required this.child});

  /// Called with -1 (swipe right → previous) or +1 (swipe left → next).
  final ValueChanged<int> onSwipe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Vertical drags pass through to the outer scroll; only a decisive
      // horizontal fling turns the page.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v <= -250) {
          onSwipe(1); // flung left → forward
        } else if (v >= 250) {
          onSwipe(-1); // flung right → back
        }
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        // Slide the incoming child in from the swipe direction, fading; the
        // outgoing one leaves the opposite way. The `_BeatSlide` carries the
        // direction so the transition reads as a page turn.
        transitionBuilder: (widget, animation) {
          final dir = widget.key is _DirectionedKey
              ? (widget.key! as _DirectionedKey).direction
              : 1;
          final begin = Offset(0.12 * dir, 0);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: begin,
                end: Offset.zero,
              ).animate(animation),
              child: widget,
            ),
          );
        },
        // The child below is keyed; wrap that key so the transition can read
        // the direction without threading it through AnimatedSwitcher.
        child: child,
      ),
    );
  }
}

/// A key that also carries the slide direction, so [_SwipeBeat]'s transition
/// builder can offset the incoming slide the right way.
@immutable
class _DirectionedKey extends ValueKey<String> {
  const _DirectionedKey(super.value, this.direction);

  final int direction;

  @override
  bool operator ==(Object other) =>
      other is _DirectionedKey &&
      other.value == value &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(value, direction);
}

// ─────────────────────────────────────────────────────────────────────────
// One beat slide
// ─────────────────────────────────────────────────────────────────────────

/// The current beat as a calm card (the mockup): eyebrow (time · kind) + a
/// small countdown when one's running → the Fraunces title → a warm tinted
/// "Say this" card of the keyLines → an italic stage cue → a call-and-response
/// chip → a "tap to expand" that reveals the FULL script. A game beat adds the
/// game block + a "Start shooting" button; a vocab beat renders word-cards.
class _BeatSlide extends StatelessWidget {
  const _BeatSlide({
    required this.beat,
    required this.expanded,
    required this.remaining,
    required this.paused,
    required this.onToggleExpand,
    required this.onStartShooting,
    super.key,
  });

  final SessionBeat beat;
  final bool expanded;
  final int? remaining;
  final bool paused;
  final VoidCallback onToggleExpand;
  final VoidCallback onStartShooting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _accentForKind(beat.kind);

    // The first stage cue (italic direction) — the one shown in the calm view.
    final firstCue = beat.script
        .where((l) => l.kind == ScriptLineKind.cue)
        .map((l) => l.text)
        .firstOrNull;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Eyebrow row: kind chip · time, + a running countdown pill.
            Row(
              children: [
                _KindEyebrow(kind: beat.kind, time: beat.time, accent: accent),
                const Spacer(),
                if (remaining != null)
                  _CountdownPill(
                    seconds: remaining!,
                    paused: paused,
                    accent: accent,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // The Fraunces title.
            Text(beat.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 14),
            // "Say this" — the calm keyLines, warm tinted by the kind accent.
            if (beat.keyLines.isNotEmpty)
              _SayThisCard(lines: beat.keyLines, accent: accent),
            // The italic stage cue (first one) — what the host DOES.
            if (firstCue != null) ...[
              const SizedBox(height: 12),
              _StageCue(text: firstCue),
            ],
            // Call-and-response chip.
            if (beat.callResponse != null &&
                beat.callResponse!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _CallResponseChip(
                call: beat.callResponse!.trim(),
                accent: accent,
              ),
            ],
            // VOCAB beat: the word cards.
            if (beat.vocabCards.isNotEmpty) ...[
              const SizedBox(height: 14),
              _VocabCards(words: beat.vocabCards, accent: accent),
            ],
            // GAME beat: the game block + "Start shooting".
            if (beat.game != null) ...[
              const SizedBox(height: 14),
              _GameBlock(
                game: beat.game!,
                accent: accent,
                onStartShooting: onStartShooting,
              ),
            ],
            // Tap to expand → the FULL script.
            const SizedBox(height: 14),
            _ExpandToggle(expanded: expanded, onTap: onToggleExpand),
            if (expanded) ...[
              const SizedBox(height: 12),
              _FullScript(lines: beat.script, accent: accent),
            ],
          ],
        ),
      ),
    );
  }
}

/// The eyebrow — a small kind chip (icon + label on the accent) and the beat's
/// time range. Colour-on-fill via [AppColors.onAccent] (never colour alone —
/// the label + icon carry the meaning).
class _KindEyebrow extends StatelessWidget {
  const _KindEyebrow({
    required this.kind,
    required this.time,
    required this.accent,
  });

  final BeatKind kind;
  final String time;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onAccent = AppColors.onAccent(accent);
    // "prep" / "after" are the untimed bookends — show the kind word only, not
    // a redundant "prep · prep".
    final isBookend = time == 'prep' || time == 'after';
    final label = isBookend ? _kindLabel(kind) : '$time · ${_kindLabel(kind)}';
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_kindIcon(kind), size: 13, color: onAccent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onAccent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The running countdown pill — `m:ss` (or "Time!" at 0), tinted by the beat
/// accent, with a pause glyph when paused. Decorative tint + an explicit label,
/// never colour alone.
class _CountdownPill extends StatelessWidget {
  const _CountdownPill({
    required this.seconds,
    required this.paused,
    required this.accent,
  });

  final int seconds;
  final bool paused;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = seconds == 0;
    // The "time's up" state reads on the theme's error tone (semantic, follows
    // dark/light); a live timer rides surfaceContainerHighest with an accent
    // ring so it's calm, not loud.
    final bg = done ? scheme.errorContainer : scheme.surfaceContainerHighest;
    final fg = done ? scheme.onErrorContainer : scheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: done ? scheme.error : accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done
                ? Icons.notifications_active_outlined
                : (paused ? Icons.pause : Icons.timer_outlined),
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            done ? 'Time!' : _mmss(seconds),
            style: theme.textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The warm tinted "Say this" card — the beat's keyLines, the lines the host
/// reads aloud, on a soft wash of the kind accent. Foreground picked for
/// contrast on that wash via [AppColors.onAccent].
class _SayThisCard extends StatelessWidget {
  const _SayThisCard({required this.lines, required this.accent});

  final List<String> lines;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A gentle wash: blend the accent toward the surface so the card is tinted,
    // not saturated. The foreground is chosen against that *washed* fill so it
    // always clears contrast (a pale wash wants dark ink; a deep one wants
    // light).
    final fill = Color.alphaBlend(
      accent.withValues(alpha: 0.16),
      theme.colorScheme.surface,
    );
    final fg = AppColors.onAccent(fill);
    final labelFg = fg.withValues(alpha: 0.75);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, size: 15, color: labelFg),
              const SizedBox(width: 6),
              Text(
                'SAY THIS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: labelFg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < lines.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == lines.length - 1 ? 0 : 8),
              child: Text(
                lines[i],
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// An italic stage-cue line — what the host DOES (not says). A walk icon + muted
/// italic text, reading as a direction beside the spoken lines.
class _StageCue extends StatelessWidget {
  const _StageCue({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.directions_walk_outlined,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// The call-and-response chip — "You: {call}" → "↳ {response}". When the call
/// carries an explicit response after a separator (→ / /) we split it; else we
/// show the kid shout-back as a generic affirm. Accent ring; labels carry it.
class _CallResponseChip extends StatelessWidget {
  const _CallResponseChip({required this.call, required this.accent});

  final String call;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // The data uses two shapes: an explicit "PHOTOGRAPHERS → SEE" (host
    // calls X, room answers Y) and a combined shout like "CLICK! / FREEZE! /
    // ASK" (the room echoes the whole thing). Render the arrow form as the
    // two-line "You: X / ↳ Y"; the no-arrow form as one "Call & response · X".
    final hasArrow = call.contains('→');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: hasArrow ? _arrowForm(theme, scheme) : _shoutForm(theme, scheme),
    );
  }

  /// "You: {call} → ↳ {response}" — the two-line call-and-response form.
  Widget _arrowForm(ThemeData theme, ColorScheme scheme) {
    final parts = call.split('→');
    final youText = parts.first.trim();
    final themText = parts.sublist(1).join('→').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'You: ',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            Expanded(
              child: Text(
                youText,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // The room's answer reads on the themed PRIMARY role (a themed
            // accent that always clears AA on the surface + follows dark/light)
            // — the kind accent is the border cue, not text.
            Icon(
              Icons.subdirectory_arrow_right,
              size: 16,
              color: scheme.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                themText,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// "Call & response · {call}" — one line for a combined shout the room echoes.
  Widget _shoutForm(ThemeData theme, ColorScheme scheme) {
    return Row(
      children: [
        Icon(Icons.campaign_outlined, size: 16, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          'Call & response: ',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        Expanded(
          child: Text(
            call,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// The vocabulary word-cards — each session-earned word as a little card
/// (the cards the host tapes to the wall). Accent-tinted; text picks contrast.
class _VocabCards extends StatelessWidget {
  const _VocabCards({required this.words, required this.accent});

  final List<String> words;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = AppColors.onAccent(accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WORDS FOR THE WALL',
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final w in words)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(Radii.card),
                ),
                child: Text(
                  w,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The game block on a game beat — the game's name, its rules as short lines,
/// and a "Start shooting" primary button that hands off to the per-child timed
/// turns.
class _GameBlock extends StatelessWidget {
  const _GameBlock({
    required this.game,
    required this.accent,
    required this.onStartShooting,
  });

  final BeatGame game;
  final Color accent;
  final VoidCallback onStartShooting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sports_esports_outlined,
                size: 18,
                color: scheme.onSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  game.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (game.minutes != null)
                Text(
                  '${game.minutes} min',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          if (game.rules.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final rule in game.rules)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 8),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        rule,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStartShooting,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Start shooting'),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "tap to expand" affordance — toggles the full script. A tertiary,
/// low-emphasis row so the calm view stays primary.
class _ExpandToggle extends StatelessWidget {
  const _ExpandToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: expanded ? 'Hide the full script' : 'Show the full script',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () {
          unawaited(HapticFeedback.selectionClick());
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                expanded ? 'Hide the full script' : 'Read the full script',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The FULL script — every [ScriptLine] in order, styled by kind: say = the
/// prominent spoken line; cue = italic muted with a walk icon; response = an
/// accent chip (the kids' shout-back); note = small muted aside.
class _FullScript extends StatelessWidget {
  const _FullScript({required this.lines, required this.accent});

  final List<ScriptLine> lines;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(Radii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < lines.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == lines.length - 1 ? 0 : 12,
                ),
                child: _ScriptLineView(line: lines[i], accent: accent),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScriptLineView extends StatelessWidget {
  const _ScriptLineView({required this.line, required this.accent});

  final ScriptLine line;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    switch (line.kind) {
      case ScriptLineKind.say:
        // The spoken line — prominent, on-surface, slightly larger.
        return Text(
          line.text,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurface,
            height: 1.4,
          ),
        );
      case ScriptLineKind.cue:
        // Stage direction — italic, muted, walk icon.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.directions_walk_outlined,
              size: 15,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                line.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
        );
      case ScriptLineKind.response:
        // The kids' shout-back — an accent chip.
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.groups_outlined,
                  size: 14,
                  color: AppColors.onAccent(accent),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    line.text,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.onAccent(accent),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      case ScriptLineKind.note:
        // An aside — small, muted.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: 14,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                line.text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
                  height: 1.4,
                ),
              ),
            ),
          ],
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// The advance bar
// ─────────────────────────────────────────────────────────────────────────

/// The pace controls + the big Next button. The timer side adapts: not started
/// → a "Start {n} min" button (only when the beat is timed); running → pause /
/// resume + stop. The Next button names the next beat so the host knows what's
/// coming; on the last beat it's disabled (the run is done).
class _AdvanceBar extends StatelessWidget {
  const _AdvanceBar({
    required this.current,
    required this.next,
    required this.remaining,
    required this.paused,
    required this.onStartCountdown,
    required this.onTogglePause,
    required this.onStopCountdown,
    required this.onNext,
  });

  final SessionBeat current;
  final SessionBeat? next;
  final int? remaining;
  final bool paused;
  final VoidCallback onStartCountdown;
  final VoidCallback onTogglePause;
  final VoidCallback onStopCountdown;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mins = current.durationMinutes;
    final timed = mins != null && mins > 0;

    return Row(
      children: [
        // Timer control. Untimed bookends (prep/after) show nothing here.
        if (timed) ...[
          if (remaining == null)
            _TimerButton(
              icon: Icons.timer_outlined,
              label: '$mins min',
              tooltip: 'Start a $mins-minute timer for this beat',
              onTap: onStartCountdown,
            )
          else ...[
            _TimerButton(
              icon: paused ? Icons.play_arrow : Icons.pause,
              label: paused ? 'Resume' : 'Pause',
              tooltip: paused ? 'Resume the timer' : 'Pause the timer',
              onTap: onTogglePause,
            ),
            const SizedBox(width: 8),
            _TimerButton(
              icon: Icons.stop_outlined,
              label: 'Stop',
              tooltip: 'Stop the timer',
              onTap: onStopCountdown,
            ),
          ],
          const SizedBox(width: 12),
        ],
        // The big Next button — names the next beat. Filled emphasis (the
        // primary verb on this surface). Disabled on the last beat.
        Expanded(
          child: FilledButton(
            onPressed: onNext,
            style: FilledButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    next == null
                        ? "That's the last beat"
                        : 'Next · ${next!.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: onNext == null
                          ? scheme.onSurfaceVariant
                          : scheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (next != null) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 18, color: scheme.onPrimary),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small tonal timer control — icon + label, ≥48dp tall, the calm secondary
/// style so it never competes with the Next button.
class _TimerButton extends StatelessWidget {
  const _TimerButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: scheme.onSurface),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// The sequence timeline
// ─────────────────────────────────────────────────────────────────────────

/// The whole run as a compact vertical timeline — one row per beat (a colored
/// dot by kind + the title + the time), the current one highlighted. Tap a row
/// to jump. Stays secondary to the slide (a quiet header + a tight list) so the
/// current beat keeps the focus.
class _SequenceTimeline extends StatelessWidget {
  const _SequenceTimeline({
    required this.beats,
    required this.current,
    required this.onJump,
  });

  final List<SessionBeat> beats;
  final int current;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'THE SEQUENCE · ${beats.length} BEATS',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ),
        // Not a builder — the run is a fixed ~17 beats, well under the
        // list-builder threshold, and we want it all visible to scan/jump.
        for (var i = 0; i < beats.length; i++)
          _TimelineRow(
            beat: beats[i],
            index: i,
            isCurrent: i == current,
            isLast: i == beats.length - 1,
            onTap: () => onJump(i),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.beat,
    required this.index,
    required this.isCurrent,
    required this.isLast,
    required this.onTap,
  });

  final SessionBeat beat;
  final int index;
  final bool isCurrent;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _accentForKind(beat.kind);

    return Semantics(
      button: true,
      selected: isCurrent,
      label:
          'Beat ${index + 1}, ${beat.title}, ${beat.time}'
          '${isCurrent ? ', current beat' : ''}',
      child: Material(
        color: isCurrent ? scheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dot + connecting line (the "timeline" spine).
                SizedBox(
                  width: 18,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: isCurrent ? accent : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent,
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 22,
                          margin: const EdgeInsets.only(top: 2),
                          color: scheme.outlineVariant,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        beat.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isCurrent
                              ? scheme.onSecondaryContainer
                              : scheme.onSurface,
                          fontWeight: isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        beat.time == 'prep' || beat.time == 'after'
                            ? _kindLabel(beat.kind)
                            : '${beat.time} · ${_kindLabel(beat.kind)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isCurrent
                              ? scheme.onSecondaryContainer.withValues(
                                  alpha: 0.85,
                                )
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(left: 6, top: 2),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      size: 18,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
