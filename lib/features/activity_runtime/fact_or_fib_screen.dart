import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/fact-or-fib` — a host-run brain break. TEACHER-paced, NO
/// typing, NO grading: a claim shows big, the room votes True or Fib (hands
/// up / move to a side), the teacher taps **Reveal** (the verdict glows + the
/// real fact appears) then **Next**. Curated content (docs/CONTENT_BANK.md).
class FactOrFibScreen extends ConsumerStatefulWidget {
  const FactOrFibScreen({super.key});

  @override
  ConsumerState<FactOrFibScreen> createState() => _FactOrFibScreenState();
}

class _FactOrFibScreenState extends ConsumerState<FactOrFibScreen> {
  late final LocalContentBank _bank;
  // Assigned in initState (after _bank), not as a field initializer.
  late final List<ContentItem> _claims;

  @override
  void initState() {
    super.initState();
    // Curated ∪ synced AI/crowd (docs/CONTENT_BANK.md); curated-only until
    // the DB tier syncs. Our own bank instance → independent seen-tracking.
    _bank = LocalContentBank(
      ref.read(bankedContentProvider).value ?? curatedSeeds,
    );
    _claims = (_bank.take(ContentKind.factOrFib, 1000)..shuffle())
        .take(10)
        .toList();
  }

  int _index = 0;
  bool _revealed = false;
  bool _done = false;

  String get _statement => _claims[_index].payload['statement']! as String;
  bool get _isTrue => _claims[_index].payload['isTrue']! as bool;
  String get _note => _claims[_index].payload['note']! as String;
  bool get _atEnd => _index >= _claims.length - 1;

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
    if (!_done) return;
    _bank.reset();
    final fresh = (_bank.take(ContentKind.factOrFib, 1000)..shuffle()).take(10);
    setState(() {
      _claims
        ..clear()
        ..addAll(fresh);
      _index = 0;
      _revealed = false;
      _done = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return EdgeScaffold(
      body: ColoredBox(
        color: Colors.black,
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
                  '${_index + 1} / ${_claims.length}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _statement,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _revealed ? '' : 'True, or fib? Vote with your hands',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Verdict(
                      label: 'True',
                      highlight: _revealed && _isTrue,
                      dim: _revealed && !_isTrue,
                    ),
                    const SizedBox(width: 16),
                    _Verdict(
                      label: 'Fib',
                      highlight: _revealed && !_isTrue,
                      dim: _revealed && _isTrue,
                    ),
                  ],
                ),
                if (_revealed) ...[
                  const SizedBox(height: 20),
                  Text(
                    _note,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
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
            const Text('🤔', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Fact-checked!',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_claims.length} claims, together.',
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

/// True / Fib slot — non-interactive; Reveal glows the right one green and
/// dims the other (never a red "wrong"; the room voted with their bodies).
class _Verdict extends StatelessWidget {
  const _Verdict({
    required this.label,
    required this.highlight,
    required this.dim,
  });

  final String label;
  final bool highlight;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? Colors.greenAccent
        : Colors.white.withValues(alpha: dim ? 0.06 : 0.14);
    final fg = highlight
        ? Colors.black87
        : Colors.white.withValues(alpha: dim ? 0.4 : 1);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 130,
      height: 84,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 28, fontWeight: FontWeight.w800),
      ),
    );
  }
}
