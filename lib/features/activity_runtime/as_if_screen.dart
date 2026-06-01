import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/kid_mode_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/as-if` — the acting / emotions / imagination game
/// (docs/ACTIVITY_RUNTIME.md). The app gives a sentence and an "as if";
/// the learner performs it out loud — "Say 'I lost my keys' AS IF you're a
/// robot." Learning through play: emotional literacy, vocal expression,
/// imagination.
///
/// This is the LIVE version: perform in the room, tap "I did it!", get a
/// new challenge; a recap of what you acted out. Recording the performance
/// (the "document" half — audio attachment, the same Storage path photos
/// use) is the next slice.
class AsIfScreen extends ConsumerStatefulWidget {
  const AsIfScreen({super.key});

  @override
  ConsumerState<AsIfScreen> createState() => _AsIfScreenState();
}

class _AsIfScreenState extends ConsumerState<AsIfScreen>
    with WidgetsBindingObserver, KidModeLock<AsIfScreen> {
  static const _route = '/activity/as-if';

  final LocalContentBank _bank = LocalContentBank.seeded();
  late final List<String> _lines;
  late final List<String> _asIfs;

  int _li = 0;
  int _ai = 0;
  int _performed = 0;
  final List<(String, String)> _history = [];
  bool _done = false;

  String get _line => _lines[_li % _lines.length];
  String get _asIf => _asIfs[_ai % _asIfs.length];

  @override
  void initState() {
    super.initState();
    _lines = [
      for (final c in _bank.take(ContentKind.line, 999))
        c.payload['text']! as String,
    ];
    _asIfs = [
      for (final c in _bank.take(ContentKind.asIf, 999))
        c.payload['text']! as String,
    ];
    enterKidLock(_route);
  }

  @override
  void dispose() {
    exitKidLock();
    super.dispose();
  }

  void _next({required bool counted}) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      if (counted) {
        _performed++;
        _history.add((_line, _asIf));
      }
      // Different cycle lengths (lines vs as-ifs) keep pairings fresh.
      _li++;
      _ai++;
    });
  }

  void _again() {
    setState(() {
      _li = 0;
      _ai = 0;
      _performed = 0;
      _history.clear();
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildKidLock(child: _done ? _recap(context) : _challenge(context));
  }

  Widget _challenge(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.theater_comedy,
                  color: Colors.amberAccent,
                  size: 44,
                ),
                const SizedBox(height: 8),
                Text(
                  'SAY IT…',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '“$_line”',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'AS IF',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.amberAccent.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    _asIf,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () => _next(counted: true),
                  icon: const Icon(Icons.check),
                  label: const Text('I did it!'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => _next(counted: false),
                  child: const Text(
                    'Another one 🎲',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _performed == 0
                      ? null
                      : () => setState(() => _done = true),
                  child: Text(
                    'Finish ($_performed)',
                    style: TextStyle(
                      color: _performed == 0 ? Colors.white24 : Colors.white,
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

  Widget _recap(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
            child: Text(
              'You acted out $_performed! 🎭',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              itemCount: _history.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final (line, asIf) = _history[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '“$line”',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'as if $asIf',
                        style: const TextStyle(color: Colors.amberAccent),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: FilledButton.tonal(
              onPressed: _again,
              child: const Text('Play again'),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Text(
              'Hand the device back to your teacher.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
