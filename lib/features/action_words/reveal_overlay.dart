import 'dart:async';

import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/widgets/become_strip.dart';
import 'package:differentworld/features/action_words/widgets/verb_lens_strip.dart';
import 'package:differentworld/features/action_words/widgets/world_badge.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One child + their day, for the closing reveal cycle.
typedef RevealItem = ({Subject subject, ActionWordsDay day});

/// The closing reveal — the day's world appears with a glow, e.g.
/// "Maya was 🐬 Dolphin today." The only loud-ish moment in a calm app.
///
/// Pushed on the ROOT navigator as an opaque fullscreen route so the app
/// chrome doesn't float over it (no immersive-provider plumbing needed),
/// and forced into a dark theme so the badge reads on black regardless of
/// the app's theme.
class RevealOverlay {
  static Future<void> show(
    BuildContext context, {
    required Subject subject,
    required ActionWordsDay day,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => _RevealPage(subject: subject, day: day),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  /// The end-of-day ceremony: reveal every child in sequence, tap to advance.
  /// Fresh-world NAMING is deferred here (it blocks the flow) — a brand-new
  /// world shows by its badge and the cycle keeps moving; naming happens later
  /// on the per-child reveal or the character sheet. No-op on an empty list.
  static Future<void> showAll(
    BuildContext context, {
    required List<RevealItem> items,
  }) {
    if (items.isEmpty) return Future<void>.value();
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => _RevealCyclePage(items: items),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

/// Fire the closing ceremony for everyone with picks today — the ONE action
/// behind both the Action Words screen's reveal button and Today's closing
/// CTA. Reads the warm, space-wide [todaysRevealItemsProvider]; a gentle nudge
/// instead of a blank ceremony when nobody's picked yet.
Future<void> revealAllPicksToday(BuildContext context, WidgetRef ref) {
  final items = ref.read(todaysRevealItemsProvider);
  if (items.isEmpty) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('No worlds to reveal yet — pick today’s words first.'),
      ),
    );
    return Future<void>.value();
  }
  return RevealOverlay.showAll(context, items: items);
}

class _RevealPage extends ConsumerStatefulWidget {
  const _RevealPage({required this.subject, required this.day});

  final Subject subject;
  final ActionWordsDay day;

  @override
  ConsumerState<_RevealPage> createState() => _RevealPageState();
}

class _RevealPageState extends ConsumerState<_RevealPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  late final TextEditingController _nameCtrl;
  bool _named = false;
  bool _naming = false;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    unawaited(_glow.repeat(reverse: true));
    _nameCtrl = TextEditingController();
    // Full drama: hide the system bars while the moment is on screen.
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    _glow.dispose();
    _nameCtrl.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  Future<void> _nameWorld() async {
    final name = _nameCtrl.text.trim();
    // Re-entry guard: a fast double-tap or button+onSubmitted both firing
    // would send two writes (the upsert is idempotent, but two concurrent
    // Drift transactions touch the same row). Mirrors _SkillMeasureSheet.
    if (name.isEmpty || _naming) return;
    setState(() {
      _naming = true;
      _named = true;
    });
    await ref
        .read(actionWordsActionsProvider)
        .setWorldName(
          subjectId: widget.subject.id,
          groupId: widget.subject.groupId,
          date: todayKey(),
          name: name,
        );
    // The page is about to close; guard so a fast back-during-write can't
    // resume into a disposed state.
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    // Resolve through the class's own world book first (continuity): a
    // combo the class already named reveals BY NAME (claimed), not as a
    // fresh world to name again.
    final book = ref.watch(classWorldBookProvider);
    final match = widget.day.hasPicks
        ? resolveWorld(widget.day.verbPicks.toSet(), book)
        : null;
    final firstName = widget.subject.firstName;
    const gold = Color(0xFFE6C079);
    final isFresh =
        match != null && match.kind == WorldMatchKind.fresh && !_named;
    final freshName = _named ? _nameCtrl.text.trim() : widget.day.worldName;

    // Dark theme so the badge + chips read on black, whatever the app theme.
    return Theme(
      // The app's dark theme (Jost + AppColors + component vocab) instead of a
      // bare ThemeData.dark — keeps the reveal in the same visual language as
      // the rest of the app. The black backdrop + gold glow below are unchanged.
      data: buildDarkTheme(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          // Tap anywhere to close — but ONLY when there's no name field on
          // screen, so a tap on the fresh-world field focuses it instead
          // of dismissing. The fresh case closes via its explicit buttons.
          onTap: isFresh ? null : () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    '$firstName was',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: gold,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (match != null)
                    _GlowingBadge(
                      glow: _glow,
                      gold: gold,
                      child: WorldBadge(
                        match: match,
                        freshName: freshName,
                        emojiSize: 104,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'today',
                    style: TextStyle(color: gold.withValues(alpha: 0.8)),
                  ),
                  // How to BECOME it — the sensory embodiment. Shown once
                  // it's a known/named world (the fresh case is busy naming).
                  if (match != null && !isFresh) ...[
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: BecomeStrip(match: match, accent: gold),
                    ),
                  ],
                  // THE LENS — same world, but the kid's three verbs shaped
                  // HOW they did it. The personalization made visible.
                  if (!isFresh && widget.day.verbPicks.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      '$firstName’s way today',
                      style: TextStyle(
                        color: gold.withValues(alpha: 0.8),
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: VerbLensStrip(
                        verbIds: widget.day.verbPicks,
                        accent: gold,
                      ),
                    ),
                  ],
                  if (isFresh) ...[
                    const SizedBox(height: 24),
                    // Let the teacher/kid name the brand-new world.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameCtrl,
                              textCapitalization: TextCapitalization.words,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: 'Name this world',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _nameWorld(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _nameWorld,
                            child: const Text('Name it'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Skip for now'),
                    ),
                  ],
                  const Spacer(),
                  if (!isFresh)
                    Text(
                      'tap to close',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
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

/// The shared reveal visual — "{name} was [glowing badge] today", optionally
/// the sensory BecomeStrip, and the verb LENS ("their way today"). Used by the
/// cycle page; the single page keeps its own inline layout (+ naming field).
class _RevealVisual extends StatelessWidget {
  const _RevealVisual({
    required this.firstName,
    required this.match,
    required this.freshName,
    required this.verbPicks,
    required this.glow,
    required this.gold,
    required this.showBecome,
    super.key,
  });

  final String firstName;
  final WorldMatch? match;
  final String? freshName;
  final List<String> verbPicks;
  final Animation<double> glow;
  final Color gold;
  final bool showBecome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$firstName was',
          textAlign: TextAlign.center,
          style: TextStyle(color: gold, fontSize: 18, letterSpacing: 1),
        ),
        const SizedBox(height: 16),
        if (match != null)
          _GlowingBadge(
            glow: glow,
            gold: gold,
            child: WorldBadge(
              match: match!,
              freshName: freshName,
              emojiSize: 104,
            ),
          ),
        const SizedBox(height: 8),
        Text('today', style: TextStyle(color: gold.withValues(alpha: 0.8))),
        if (match != null && showBecome) ...[
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: BecomeStrip(match: match!, accent: gold),
          ),
        ],
        if (verbPicks.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            '$firstName’s way today',
            style: TextStyle(
              color: gold.withValues(alpha: 0.8),
              fontSize: 13,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: VerbLensStrip(verbIds: verbPicks, accent: gold),
          ),
        ],
      ],
    );
  }
}

/// The closing CEREMONY — reveal each child in turn, tap to advance. One glow
/// controller for the whole run; the index walks the list; the last tap pops.
/// Naming is deferred (no fresh-world field) so the flow never stalls.
class _RevealCyclePage extends ConsumerStatefulWidget {
  const _RevealCyclePage({required this.items});

  final List<RevealItem> items;

  @override
  ConsumerState<_RevealCyclePage> createState() => _RevealCyclePageState();
}

class _RevealCyclePageState extends ConsumerState<_RevealCyclePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    unawaited(_glow.repeat(reverse: true));
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void dispose() {
    _glow.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  void _advance() {
    if (_i + 1 >= widget.items.length) {
      unawaited(Navigator.of(context).maybePop());
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(classWorldBookProvider);
    final item = widget.items[_i];
    final day = item.day;
    final match = day.hasPicks
        ? resolveWorld(day.verbPicks.toSet(), book)
        : null;
    final isFresh = match != null && match.kind == WorldMatchKind.fresh;
    const gold = Color(0xFFE6C079);
    final n = widget.items.length;
    final isLast = _i + 1 >= n;

    return Theme(
      // The app's dark theme (Jost + AppColors + component vocab) instead of a
      // bare ThemeData.dark — keeps the reveal in the same visual language as
      // the rest of the app. The black backdrop + gold glow below are unchanged.
      data: buildDarkTheme(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _advance,
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_i + 1} / $n',
                      style: TextStyle(
                        color: gold.withValues(alpha: 0.7),
                        fontSize: 13,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Keyed by index so the glow/badge cross-fade reads as a new
                  // child each advance, not a mutation of the last one.
                  _RevealVisual(
                    key: ValueKey('reveal-${item.subject.id}'),
                    firstName: item.subject.firstName,
                    match: match,
                    // Naming deferred — show whatever auto-name exists, if any.
                    freshName: day.worldName,
                    verbPicks: day.verbPicks,
                    glow: _glow,
                    gold: gold,
                    showBecome: !isFresh,
                  ),
                  const Spacer(),
                  Text(
                    isLast ? 'tap to finish' : 'tap for the next',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
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

/// A soft radial glow that breathes behind the world badge.
class _GlowingBadge extends StatelessWidget {
  const _GlowingBadge({
    required this.glow,
    required this.gold,
    required this.child,
  });

  final Animation<double> glow;
  final Color gold;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, child) {
        final t = 0.45 + glow.value * 0.55; // breathe 0.45 → 1.0
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.22 * t),
                blurRadius: 60 * t,
                spreadRadius: 24 * t,
              ),
            ],
          ),
          child: child,
        );
      },
      child: child,
    );
  }
}
