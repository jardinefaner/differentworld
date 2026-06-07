import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/widgets/become_strip.dart';
import 'package:differentworld/features/action_words/widgets/world_badge.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    if (name.isEmpty) return;
    setState(() => _named = true);
    await ref.read(actionWordsActionsProvider).setWorldName(
          subjectId: widget.subject.id,
          groupId: widget.subject.groupId,
          date: todayKey(),
          name: name,
        );
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
      data: ThemeData.dark(useMaterial3: true),
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
