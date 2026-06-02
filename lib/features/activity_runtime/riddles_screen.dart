import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/presenter_shortcuts.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/riddles` — a host-run brain break. TEACHER-paced, NO typing,
/// NO grading: one riddle at a time, big; the room shouts guesses ALOUD;
/// the teacher taps **Reveal** (the answer appears, celebratory) then
/// **Next**. Content is curated + answer-first (docs/CONTENT_BANK.md).
class RiddlesScreen extends ConsumerStatefulWidget {
  const RiddlesScreen({super.key});

  @override
  ConsumerState<RiddlesScreen> createState() => _RiddlesScreenState();
}

class _RiddlesScreenState extends ConsumerState<RiddlesScreen> {
  late final LocalContentBank _bank;
  // Take the whole pool, shuffle, keep 10 — so repeat sessions don't always
  // surface the same first ten. Assigned in initState (after _bank), not as
  // a field initializer, so the read order is obvious.
  late final List<ContentItem> _riddles;

  @override
  void initState() {
    super.initState();
    // Curated ∪ synced AI/crowd (docs/CONTENT_BANK.md); curated-only until
    // the DB tier syncs. Our own bank instance → independent seen-tracking.
    _bank = LocalContentBank(
      ref.read(bankedContentProvider).value ?? curatedSeeds,
    );
    _riddles = (_bank.take(ContentKind.riddle, 1000)..shuffle())
        .take(10)
        .toList();
  }

  int _index = 0;
  bool _revealed = false;
  bool _done = false;

  String get _prompt => _riddles[_index].payload['prompt']! as String;
  String get _answer => _riddles[_index].payload['answer']! as String;
  bool get _atEnd => _index >= _riddles.length - 1;

  void _reveal() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _revealed = true);
  }

  void _next() {
    if (_atEnd) {
      setState(() => _done = true);
      return;
    }
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  void _again() {
    if (!_done) return; // idempotent: only reachable from the recap
    _bank.reset();
    final fresh = (_bank.take(ContentKind.riddle, 1000)..shuffle()).take(10);
    setState(() {
      _riddles
        ..clear()
        ..addAll(fresh);
      _index = 0;
      _revealed = false;
      _done = false; // last: a mid-transition re-tap finds _done already false
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      // Presenter keyboard controls (docs/PLATFORM_RUBRIC.md, P3):
      // Space/R reveals the answer, → / Enter advances.
      body: PresenterShortcuts(
        onReveal: _done ? null : _reveal,
        onNext: _done ? null : _next,
        child: ColoredBox(
          color: Colors.black,
          child: SafeArea(child: _done ? _recap(context) : _game(context)),
        ),
      ),
    );
  }

  Widget _game(BuildContext context) {
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
                Text(
                  '${_index + 1} / ${_riddles.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _prompt,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _revealed ? 'There it is!' : 'Say your guess — then Reveal',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 28),
                _AnswerCard(answer: _answer, revealed: _revealed),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _revealed ? _next : _reveal,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                    ),
                    icon: Icon(
                      _revealed
                          ? (_atEnd ? Icons.emoji_events : Icons.arrow_forward)
                          : Icons.visibility_outlined,
                    ),
                    label: Text(
                      _revealed
                          ? (_atEnd ? 'See the round' : 'Next')
                          : 'Reveal',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧠', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Nice riddling!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_riddles.length} riddles, together.',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 28),
            FilledButton.tonal(
              onPressed: _again,
              child: const Text('Play again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The answer slot — a dim "?" until Reveal, then a celebratory glow (never
/// graded; the room already said it out loud).
class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.answer, required this.revealed});

  final String answer;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 88),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: revealed
            ? Colors.greenAccent
            : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        revealed ? answer : '?',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: revealed ? Colors.black87 : Colors.white24,
          fontSize: revealed ? 30 : 40,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
