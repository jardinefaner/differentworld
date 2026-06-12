import 'dart:async';

import 'package:differentworld/app/theme.dart';
import 'package:differentworld/features/spells/spells.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app dark theme, computed once (not per `setState` rebuild).
final ThemeData _darkTheme = buildDarkTheme();

/// Casts a spell — a fullscreen dark countdown (the brief's one loud
/// moment): the big emoji breathes, the foreign **word** leads, a timer
/// ticks down. Pushed on the root navigator so no app chrome floats over
/// it; tap anywhere to end early. Show it on a projector or hold up the
/// phone.
class SpellOverlay {
  static Future<void> cast(BuildContext context, Spell spell) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => _SpellPage(spell: spell),
        transitionsBuilder: (_, anim, _, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }
}

class _SpellPage extends StatefulWidget {
  const _SpellPage({required this.spell});

  final Spell spell;

  @override
  State<_SpellPage> createState() => _SpellPageState();
}

class _SpellPageState extends State<_SpellPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  late final SpellWord _word;
  Timer? _ticker;
  late int _remaining;

  static const _gold = Color(0xFFE6C079);

  @override
  void initState() {
    super.initState();
    _word = spellWordForDay(widget.spell, todayKey());
    _remaining = widget.spell.durationSeconds;
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    unawaited(_breath.repeat(reverse: true));
    _ticker = Timer.periodic(const Duration(seconds: 1), _tick);
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  void _tick(Timer t) {
    if (!mounted) return;
    if (_remaining <= 0) {
      t.cancel();
      unawaited(HapticFeedback.mediumImpact());
      return;
    }
    setState(() => _remaining -= 1);
    if (_remaining == 0) {
      t.cancel();
      unawaited(HapticFeedback.mediumImpact());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _breath.dispose();
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _remaining <= 0;
    return Theme(
      data: _darkTheme,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.08)
                        .animate(CurvedAnimation(
                      parent: _breath,
                      curve: Curves.easeInOut,
                    )),
                    child: Text(
                      widget.spell.emoji,
                      style: const TextStyle(fontSize: 120),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _word.word,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _gold,
                      fontSize: 52,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_word.pronunciation}  ·  ${_word.language}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '“${_word.meaning}”  ·  ${widget.spell.english}',
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    done ? 'Time!' : spellTimeLabel(_remaining),
                    style: TextStyle(
                      color: done ? _gold : Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'tap to end',
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
