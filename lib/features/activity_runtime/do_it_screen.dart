import 'dart:async';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/do-it` — the **"Do It"** activity (docs/VISION.md 2026-06-18).
///
/// One real-world action at a time, big on the room screen: build · find ·
/// move · make · ask · help. The room gets up and DOES it; the teacher taps
/// **We did it!** and — unlike the ephemeral games — it leaves a persistent,
/// accumulating `EntryKind.didIt` record (a room/program entry that stacks into
/// the day + the Book). v1 is the quick-tap loop; photo proof + per-child
/// "who led it" tagging are the next slice (`recordDidIt` already takes them).
class DoItScreen extends ConsumerStatefulWidget {
  const DoItScreen({this.groupId, super.key});

  /// The cohort doing it, when launched from a room. Null → a program-wide
  /// record (the "room record" still lands; per-cohort scoping is opt-in).
  final String? groupId;

  @override
  ConsumerState<DoItScreen> createState() => _DoItScreenState();
}

class _DoItScreenState extends ConsumerState<DoItScreen> {
  int _index = 0;
  bool _saving = false;
  // The shuffled order is fixed for the session so "Next" always advances to
  // something new (and a re-open re-shuffles). Built lazily from the bank.
  List<ContentItem>? _deck;

  List<ContentItem> _deckFrom(List<ContentItem> items) {
    final existing = _deck;
    if (existing != null) return existing;
    final doIts = items.where((i) => i.kind == ContentKind.doIt).toList()
      ..shuffle();
    _deck = doIts;
    return doIts;
  }

  Future<void> _markDone(ContentItem item) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref
          .read(entryActionsProvider)
          .recordDidIt(
            instruction: (item.payload['text'] as String?) ?? '',
            verb: (item.payload['verb'] as String?) ?? 'do',
            groupId: widget.groupId,
          );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Nice — saved to your record.')),
        );
      _next();
    } on Object catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save that — try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = ref.watch(bankedContentProvider).value ?? curatedSeeds;
    final deck = _deckFrom(items);

    return EdgeScaffold(
      body: deck.isEmpty
          ? const EmptyState(
              icon: Icons.directions_run_outlined,
              title: 'Nothing to do yet',
              message:
                  'Real-world actions will appear here to try with the '
                  'room.',
            )
          : _present(theme, scheme, deck[_index % deck.length]),
    );
  }

  Widget _present(ThemeData theme, ColorScheme scheme, ContentItem item) {
    final text = (item.payload['text'] as String?) ?? '';
    final emoji = (item.payload['emoji'] as String?) ?? '✨';
    final verb = (item.payload['verb'] as String?) ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Do it', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (verb.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      verb,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // The action, big — host-present, glanceable across the room.
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 64)),
                    const SizedBox(height: 20),
                    Text(
                      text,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _next,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _markDone(item),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('We did it!'),
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
