import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/activity_runtime/letters.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/activity_prompt.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/letters` — **Letters** (docs/VISION.md 2026-06-19): the room
/// writes notes to each other. Host-present, paper-first (no kid phone) — the
/// app gives a kind prompt and pairs the cohort into a write-to cycle so
/// everyone writes one note and everyone gets one. The kids write on paper with
/// "To:" / "From:" at the top. Teacher-paced, ephemeral.
class LettersScreen extends ConsumerStatefulWidget {
  const LettersScreen({this.groupId, super.key});

  /// Optional starting cohort (from `?group=`); otherwise the first.
  final String? groupId;

  @override
  ConsumerState<LettersScreen> createState() => _LettersScreenState();
}

class _LettersScreenState extends ConsumerState<LettersScreen> {
  String? _groupId;
  List<ContentItem>? _promptDeck;
  int _promptIndex = 0;
  int _salt = 1;

  @override
  void initState() {
    super.initState();
    _groupId = widget.groupId;
  }

  List<ContentItem> _prompts(List<ContentItem> items) {
    final existing = _promptDeck;
    if (existing != null) return existing;
    final p = items.where((i) => i.kind == ContentKind.writePrompt).toList()
      ..shuffle();
    _promptDeck = p;
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = ref.watch(bankedContentProvider).value ?? curatedSeeds;
    final prompts = _prompts(items);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final selected = groups.isEmpty
        ? null
        : groups.firstWhere(
            (g) => g.id == _groupId,
            orElse: () => groups.first,
          );
    final roster = selected == null
        ? const <Subject>[]
        : (ref.watch(subjectsInGroupProvider(selected.id)).value ??
              const <Subject>[]);
    final prompt = prompts.isEmpty
        ? null
        : (prompts[_promptIndex % prompts.length].payload['text'] as String?) ??
              '';
    final pairs = letterPairs(roster, _salt);

    return EdgeScaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'Letters',
            ),
            if (groups.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final g in groups)
                      ChoiceChip(
                        label: Text(g.name),
                        selected: g.id == selected?.id,
                        onSelected: (_) => setState(() => _groupId = g.id),
                      ),
                  ],
                ),
              ),
            if (prompt != null && prompt.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ActivityPrompt(
                  eyebrow: 'Today’s prompt',
                  prompt: prompt,
                  padding: const EdgeInsets.all(18),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      unawaited(HapticFeedback.selectionClick());
                      setState(() => _promptIndex++);
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('New prompt'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pairs.isEmpty
                        ? null
                        : () {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() => _salt++);
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text('Shuffle pairs'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (pairs.isEmpty)
              _NoPairsNote(hasGroups: groups.isNotEmpty)
            else ...[
              // "everyone writes one, gets one" described the list directly
              // under it — every name appears once on each side, with an
              // arrow between. And "Write it on paper" was a permanent
              // how-to: true forever, which is why it stopped being read.
              // The paper instruction belongs where it is NEWS — the empty
              // state, before there is anything else to look at.
              Text(
                'Today’s pairs',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final pair in pairs)
                _PairRow(from: pair.from.firstName, to: pair.to.firstName),
            ],
          ],
        ),
      ),
    );
  }
}

/// One from → to pairing in the cycle.
class _PairRow extends StatelessWidget {
  const _PairRow({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              from,
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.edit_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              to,
              textAlign: TextAlign.right,
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the cohort can't be paired (fewer than two children) — the
/// activity still works, the kids just pick a friend themselves. A plain
/// (non-scrolling) note: it's a ListView child, so it must NOT use EmptyState,
/// which wraps itself in a CenterOrScroll viewport (unbounded inside a list).
class _NoPairsNote extends StatelessWidget {
  const _NoPairsNote({required this.hasGroups});

  final bool hasGroups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.mail_outline,
            size: 48,
            color: scheme.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Write to a friend',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hasGroups
                ? 'Add more children to this room to pair everyone up — or '
                      'just pick a friend and write them a note.'
                : 'Pick a friend and write them a note — put “To:” and “From:” '
                      'at the top.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
