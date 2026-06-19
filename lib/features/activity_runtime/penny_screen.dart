import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/penny` — **Penny for a Thought** (docs/VISION.md 2026-06-19):
/// "a penny for a thought… it's math, it's counting." Share a thought, drop a
/// penny; the pile of pennies is the math. Host-present: a question sparks the
/// thoughts, each one taps a penny into the jar, and the room counts them
/// together — laid out in rows of ten so they can count by tens. Sharing +
/// counting in one. Teacher-paced, ephemeral.
class PennyScreen extends ConsumerStatefulWidget {
  const PennyScreen({super.key});

  @override
  ConsumerState<PennyScreen> createState() => _PennyScreenState();
}

class _PennyScreenState extends ConsumerState<PennyScreen> {
  int _count = 0;
  List<ContentItem>? _qDeck;
  int _qIndex = 0;

  // Cap the drawn pennies so a runaway tap-fest doesn't lay out thousands of
  // circles; the number still counts up past it.
  static const int _maxDrawn = 100;

  List<ContentItem> _questions(List<ContentItem> items) {
    final existing = _qDeck;
    if (existing != null) return existing;
    final q = items.where((i) => i.kind == ContentKind.question).toList()
      ..shuffle();
    _qDeck = q;
    return q;
  }

  void _addPenny() {
    unawaited(HapticFeedback.lightImpact());
    setState(() => _count++);
  }

  void _undo() {
    if (_count == 0) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _count--);
  }

  void _startOver() {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _count = 0);
  }

  void _newQuestion() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _qIndex++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = ref.watch(bankedContentProvider).value ?? curatedSeeds;
    final questions = _questions(items);
    final question = questions.isEmpty
        ? null
        : (questions[_qIndex % questions.length].payload['text'] as String?);

    return EdgeScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'Penny for a thought',
              subtitle: 'Share a thought — drop a penny — count them',
            ),
            if (question != null && question.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'a thought about…',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      question,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            // The count, big — the answer to "how many thoughts?"
            Center(
              child: Column(
                children: [
                  Text(
                    '$_count',
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                  Text(
                    _count == 1
                        ? 'penny · 1 thought'
                        : 'pennies · $_count thoughts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _PennyPile(count: _count, max: _maxDrawn),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _addPenny,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(60),
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('A penny for a thought'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _count == 0 ? null : _undo,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Undo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _newQuestion,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('New question'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _count == 0 ? null : _startOver,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('Start over'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The pile of pennies, laid out in rows of ten so the room can count by tens
/// (the place-value math) — copper circles, the last partial row trailing.
class _PennyPile extends StatelessWidget {
  const _PennyPile({required this.count, required this.max});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (count == 0) {
      return Center(
        child: Text(
          'No pennies yet — tap to add the first thought.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final drawn = count > max ? max : count;
    final overflow = count - drawn;
    return Column(
      children: [
        // Rows of ten so the room can count by tens (the place-value math).
        for (var start = 0; start < drawn; start += 10)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (
                  var i = start;
                  i < (start + 10 < drawn ? start + 10 : drawn);
                  i++
                )
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 3),
                    // A penny is iconographically copper — a content visual,
                    // like an emoji; the themed text sits around it.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ActivityPalette.amber,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 20, height: 20),
                    ),
                  ),
              ],
            ),
          ),
        if (overflow > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '+$overflow more',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
