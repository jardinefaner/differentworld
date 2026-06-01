import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/kid_mode_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/this-or-that` — a kid-friendly binary-choice game
/// (docs/ACTIVITY_RUNTIME.md). One pair fills the screen as two tappable
/// halves; tap your pick, the next pair slides in; at the end, a recap of
/// your choices. Content comes from the content bank (curated now, DB +
/// AI-grown later) — served once, no repeats.
///
/// Single-device for now: the recap shows YOUR picks. The "room's split"
/// (everyone's choices aggregated) lands when picks persist + sync
/// (SUBMISSIONS-style), the same way photography uploads.
class ThisOrThatScreen extends ConsumerStatefulWidget {
  const ThisOrThatScreen({super.key});

  @override
  ConsumerState<ThisOrThatScreen> createState() => _ThisOrThatScreenState();
}

class _ThisOrThatScreenState extends ConsumerState<ThisOrThatScreen>
    with WidgetsBindingObserver, KidModeLock<ThisOrThatScreen> {
  static const _route = '/activity/this-or-that';
  static const _roundSize = 8;

  final LocalContentBank _bank = LocalContentBank.seeded();
  late List<ContentItem> _pairs;

  /// fingerprint → 'a' | 'b'
  final Map<String, String> _choice = {};
  int _index = 0;

  // A small playful palette; each pair gets its own two-tone split.
  static const _palette = <(Color, Color)>[
    (Color(0xFFEF5350), Color(0xFF42A5F5)),
    (Color(0xFFFFA726), Color(0xFF26A69A)),
    (Color(0xFFAB47BC), Color(0xFF66BB6A)),
    (Color(0xFF5C6BC0), Color(0xFFFFCA28)),
    (Color(0xFFEC407A), Color(0xFF29B6F6)),
  ];

  bool get _done => _index >= _pairs.length;

  @override
  void initState() {
    super.initState();
    _pairs = _bank.take(ContentKind.thisOrThat, _roundSize);
    enterKidLock(_route);
  }

  @override
  void dispose() {
    exitKidLock();
    super.dispose();
  }

  void _pick(String side) {
    if (_done) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _choice[_pairs[_index].fingerprint] = side;
      _index++;
    });
  }

  void _again() {
    _bank.reset();
    setState(() {
      _pairs = _bank.take(ContentKind.thisOrThat, _roundSize);
      _choice.clear();
      _index = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildKidLock(child: _done ? _recap(context) : _round(context));
  }

  Widget _round(BuildContext context) {
    final pair = _pairs[_index];
    final a = pair.payload['a']! as String;
    final b = pair.payload['b']! as String;
    final (colorA, colorB) = _palette[_index % _palette.length];

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: _half(text: a, color: colorA, onTap: () => _pick('a')),
            ),
            Expanded(
              child: _half(text: b, color: colorB, onTap: () => _pick('b')),
            ),
          ],
        ),
        // The "OR" badge straddling the seam.
        const Center(child: _OrBadge()),
        // Progress, top-center (clear of the staff corner at top-left).
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '${_index + 1} / ${_pairs.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _half({
    required String text,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.28)!],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1.1,
                shadows: [Shadow(color: Colors.black38, blurRadius: 6)],
              ),
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
              'Your picks',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              itemCount: _pairs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final pair = _pairs[i];
                final chosen = _choice[pair.fingerprint];
                final a = pair.payload['a']! as String;
                final b = pair.payload['b']! as String;
                return _RecapRow(
                  a: a,
                  b: b,
                  chose: chosen, // 'a' | 'b' | null
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

class _OrBadge extends StatelessWidget {
  const _OrBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'OR',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.a, required this.b, required this.chose});

  final String a;
  final String b;
  final String? chose;

  @override
  Widget build(BuildContext context) {
    Widget side(String text, {required bool picked}) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: picked
              ? Colors.pinkAccent.withValues(alpha: 0.9)
              : Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (picked) ...[
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: picked ? Colors.white : Colors.white60,
                  fontWeight: picked ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        side(a, picked: chose == 'a'),
        const SizedBox(width: 8),
        side(b, picked: chose == 'b'),
      ],
    );
  }
}
