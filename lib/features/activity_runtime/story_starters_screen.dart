import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/story` — Story Starters. A host-run imagination break: an
/// opener shows big, the room builds the story aloud one line each around
/// the circle, and the teacher can drop a "Plot twist!" card any time, then
/// move to a new start. No typing, no grading — pure invention.
class StoryStartersScreen extends ConsumerStatefulWidget {
  const StoryStartersScreen({super.key});

  @override
  ConsumerState<StoryStartersScreen> createState() =>
      _StoryStartersScreenState();
}

class _StoryStartersScreenState extends ConsumerState<StoryStartersScreen> {
  late final LocalContentBank _bank;
  late final List<ContentItem> _starters = (_bank.take(
    ContentKind.storyStarter,
    1000,
  )..shuffle()).take(8).toList();
  late final List<ContentItem> _twists = _bank.take(
    ContentKind.storyTwist,
    1000,
  )..shuffle();

  @override
  void initState() {
    super.initState();
    // Curated ∪ synced AI/crowd (docs/CONTENT_BANK.md); curated-only until
    // the DB tier syncs. Our own bank instance → independent seen-tracking.
    _bank = LocalContentBank(
      ref.read(bankedContentProvider).value ?? curatedSeeds,
    );
  }

  int _index = 0;
  int _twistI = 0;
  String? _twist; // the current plot twist, if one has been dropped
  bool _done = false;

  String get _starter => _starters[_index].payload['text']! as String;
  bool get _atEnd => _index >= _starters.length - 1;

  void _addTwist() {
    if (_twists.isEmpty) return;
    setState(() {
      _twist = _twists[_twistI % _twists.length].payload['text']! as String;
      _twistI++;
    });
  }

  void _nextStart() {
    if (_atEnd) {
      setState(() => _done = true);
      return;
    }
    setState(() {
      _index++;
      _twist = null;
    });
  }

  void _again() {
    if (!_done) return;
    _bank.reset();
    final fresh = (_bank.take(ContentKind.storyStarter, 1000)..shuffle()).take(
      8,
    );
    setState(() {
      _starters
        ..clear()
        ..addAll(fresh);
      _index = 0;
      _twist = null;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: const Color(0xFF1B1430),
        child: SafeArea(child: _done ? _recap(context) : _game(context)),
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
                  'Story ${_index + 1} / ${_starters.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _starter,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Build it together — one line each, around the circle.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                if (_twist != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.amberAccent.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '✨ PLOT TWIST',
                          style: TextStyle(
                            color: Colors.amberAccent,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _twist!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: _twists.isEmpty ? null : _addTwist,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amberAccent,
                    side: BorderSide(
                      color: Colors.amberAccent.withValues(alpha: 0.6),
                    ),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(_twist == null ? 'Add a twist' : 'Another twist'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _nextStart,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                    ),
                    icon: Icon(
                      _atEnd ? Icons.emoji_events : Icons.arrow_forward,
                    ),
                    label: Text(
                      _atEnd ? 'See the round' : 'New start',
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
            const Text('📖', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'What a story!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_starters.length} stories, all yours.',
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
