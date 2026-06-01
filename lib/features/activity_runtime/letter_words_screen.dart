import 'dart:async';
import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `/activity/starts-with` — "name things that start with this letter."
///
/// TEACHER-paced, NO typing, NO right/wrong (docs/ACTIVITY_ROADMAP.md Wave
/// 2). The room sees a big letter + a category and shouts answers ALOUD;
/// the teacher taps the tally as they come, then advances. A count, never
/// a graded word-list. All 26 letters — the teacher just Nexts past any
/// that are too hard for the room.
class LetterWordsScreen extends StatefulWidget {
  const LetterWordsScreen({super.key});

  @override
  State<LetterWordsScreen> createState() => _LetterWordsScreenState();
}

class _LetterWordsScreenState extends State<LetterWordsScreen> {
  static const _letters = [
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', //
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  final LocalContentBank _bank = LocalContentBank.seeded();
  final Random _rng = Random();

  late ContentItem _category;
  late String _letter;
  int _count = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _category = _bank.next(ContentKind.category) ?? _fallbackCategory();
    _letter = _letters[_rng.nextInt(_letters.length)];
  }

  ContentItem _fallbackCategory() => const ContentItem(
    kind: ContentKind.category,
    fingerprint: 'a-word',
    payload: {'label': 'a word'},
  );

  String get _categoryLabel => _category.payload['label']! as String;

  void _tally() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _count++);
  }

  void _nextRound() {
    setState(() {
      var pick = _letters[_rng.nextInt(_letters.length)];
      while (pick == _letter && _letters.length > 1) {
        pick = _letters[_rng.nextInt(_letters.length)];
      }
      _letter = pick;
      _category =
          _bank.next(ContentKind.category) ??
          (_bank..reset()).next(ContentKind.category) ??
          _fallbackCategory();
      _count = 0;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: Colors.black,
        child: SafeArea(
          child: _done ? _recap(context) : _play(context),
        ),
      ),
    );
  }

  Widget _play(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _BigLetter(letter: _letter),
                const SizedBox(height: 20),
                Text(
                  'Name $_categoryLabel that starts with $_letter',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The room shouts them out — you keep the tally.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '$_count',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.amberAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'found',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _tally,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    icon: const Icon(Icons.add, size: 26),
                    label: const Text(
                      'Someone said it',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _nextRound,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('New letter'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _count == 0
                            ? null
                            : () => setState(() => _done = true),
                        icon: const Icon(Icons.flag_outlined),
                        label: const Text('Done'),
                      ),
                    ),
                  ],
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
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text(
                  'The room found $_count!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_categoryLabel that starts with $_letter',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 28),
                FilledButton.tonal(
                  onPressed: _nextRound,
                  child: const Text('New round'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The letter, big — the room reads it across the room.
class _BigLetter extends StatelessWidget {
  const _BigLetter({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 128,
      decoration: const BoxDecoration(
        color: Colors.amberAccent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 76,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
