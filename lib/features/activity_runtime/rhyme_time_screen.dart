import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/rhyme-time` — a host-run word break. TEACHER-paced, NO typing,
/// NO grading: a word shows big, the room shouts rhymes ALOUD, the teacher
/// taps the tally each time. Change the word any time; the count climbs for
/// the whole room. (Same spirit as Beat the Letter.)
class RhymeTimeScreen extends ConsumerStatefulWidget {
  const RhymeTimeScreen({super.key});

  @override
  ConsumerState<RhymeTimeScreen> createState() => _RhymeTimeScreenState();
}

class _RhymeTimeScreenState extends ConsumerState<RhymeTimeScreen> {
  late final LocalContentBank _bank;
  // Assigned in initState (after _bank), not as a field initializer.
  late final List<ContentItem> _words;

  @override
  void initState() {
    super.initState();
    // Curated ∪ synced AI/crowd (docs/CONTENT_BANK.md); curated-only until
    // the DB tier syncs. Our own bank instance → independent seen-tracking.
    _bank = LocalContentBank(
      ref.read(bankedContentProvider).value ?? curatedSeeds,
    );
    _words = _bank.take(ContentKind.rhymeWord, 1000)..shuffle();
  }

  int _index = 0;
  int _count = 0;
  bool _done = false;

  String get _word => _words[_index].payload['word']! as String;

  void _rhymed() => setState(() => _count++);

  void _newWord() {
    setState(() => _index = (_index + 1) % _words.length);
  }

  void _finish() => setState(() => _done = true);

  void _again() {
    if (!_done) return;
    _bank.reset();
    final fresh = _bank.take(ContentKind.rhymeWord, 1000)..shuffle();
    setState(() {
      _words
        ..clear()
        ..addAll(fresh);
      _index = 0;
      _count = 0;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: Colors.black,
        child: SafeArea(child: _done ? _recap(context) : _play(context)),
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
                const Text(
                  'RHYME WITH',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _word,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'How many rhymes can the room find?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  '$_count',
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text('found', style: TextStyle(color: Colors.white38)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _rhymed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(64),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text(
                      'Someone rhymed it!',
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
                        onPressed: _newWord,
                        icon: const Icon(Icons.skip_next),
                        label: const Text('New word'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _count > 0 ? _finish : null,
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎤', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'The room found $_count!',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Rhymes, all together.',
              style: TextStyle(color: Colors.white60),
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
