import 'dart:async';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/rotation/rotation_engine.dart';
import 'package:differentworld/features/rotation/rotation_providers.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/shell_metrics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Make groups — the instrument (docs/ROTATION.md).
///
/// Not a randomiser. It knows who is here today and who has already worked
/// with whom, so "shuffle" means *give these children a configuration they
/// have not recently had*. The result reports the MIX ("10 new · 2
/// unavoidable repeats") rather than a bare warning count, and says WHEN a
/// repeated pair last met — a repeat marker with no referent is an alarm,
/// and this is not an alarm.
///
/// Per the half-second rule: what you read is at the top, the control you
/// press repeatedly is at the bottom, and the reveal is deliberately slow
/// (instant results feel rigged; a beat of animation feels fair).
class ArrangeScreen extends ConsumerStatefulWidget {
  const ArrangeScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<ArrangeScreen> createState() => _ArrangeScreenState();
}

class _ArrangeScreenState extends ConsumerState<ArrangeScreen> {
  SplitMode _mode = SplitMode.groupsOf;
  int _n = 3;
  RemainderPolicy _remainder = RemainderPolicy.absorb;
  RotationResult? _result;
  bool _revealing = false;
  bool _kept = false;

  /// Only the children actually here. Absence is the most common real-world
  /// need by a wide margin — nobody wants to remove a child because they
  /// have the flu today.
  List<Subject> _present(List<Subject> roster) {
    final records =
        ref
            .watch(
              attendanceForDayProvider((
                groupId: widget.groupId,
                date: todayKey(),
              )),
            )
            .value ??
        const <AttendanceRecord>[];
    if (records.isEmpty) return roster;
    final away = {
      for (final r in records)
        if (r.status != 'present' && r.status != 'late') r.subjectId,
    };
    return [
      for (final s in roster)
        if (!away.contains(s.id)) s,
    ];
  }

  Future<void> _shuffle(List<Subject> present) async {
    if (_revealing) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _revealing = true;
      _kept = false;
    });
    final history = ref.read(rotationHistoryProvider(widget.groupId));
    final rounds = ref.read(roundsForGroupProvider(widget.groupId)).value;
    final result = const RotationEngine().arrange(
      RotationRequest(
        presentIds: [for (final s in present) s.id],
        mode: _mode,
        n: _n,
        round: (rounds?.isEmpty ?? true) ? 1 : rounds!.first.roundNo + 1,
        remainder: _remainder,
        history: history,
      ),
    );
    // A beat before the answer. Instant results feel rigged; this is the one
    // place in the app where slower is better (CLAUDE.md, half-second rule).
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _result = result;
      _revealing = false;
    });
  }

  Future<void> _keep() async {
    final result = _result;
    if (result == null || _kept) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _kept = true);
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(rotationActionsProvider)
        .keep(
          groupId: widget.groupId,
          result: result,
          mode: _mode,
          n: _n,
          remainder: _remainder,
        );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Kept — ${result.newPairs} new '
          '${result.newPairs == 1 ? 'pairing' : 'pairings'}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = (ref.watch(groupsProvider).value ?? const <Group>[])
        .where((g) => g.id == widget.groupId)
        .firstOrNull;
    final roster =
        ref.watch(subjectsInGroupProvider(widget.groupId)).value ??
        const <Subject>[];
    final present = _present(roster);
    final names = {for (final s in roster) s.id: s.firstName};
    final result = _result;
    final sizes = RotationEngine.planSizes(
      total: present.length,
      mode: _mode,
      n: _n,
      remainder: _remainder,
    );

    return EdgeScaffold(
      backFallbackRoute: '/groups/${widget.groupId}',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    children: [
                      ContentHeader(
                        title: 'Make groups',
                        subtitle: group == null
                            ? null
                            : '${group.name} · ${present.length} here today',
                      ),
                      if (present.length < 2)
                        const EmptyState(
                          icon: Icons.groups_outlined,
                          title: 'Not enough children here',
                          message:
                              'Two or more need to be present before there '
                              'is anything to arrange.',
                        )
                      else ...[
                        _Controls(
                          mode: _mode,
                          n: _n,
                          remainder: _remainder,
                          sizes: sizes,
                          onMode: (m) => setState(() => _mode = m),
                          onN: (v) => setState(() => _n = v),
                          onRemainder: (r) => setState(() => _remainder = r),
                        ),
                        const SizedBox(height: 20),
                        if (_revealing)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (result != null)
                          _Reveal(
                            result: result,
                            names: names,
                            kept: _kept,
                          ),
                      ],
                    ],
                  ),
                ),
                // The thumb owns the bottom: the control you press over and
                // over lives here, not in the top chrome pill. It is a FIXED
                // control, so it clears the LIVE strip that floats over the
                // body's bottom edge (see ShellMetrics.liveStripHeight) —
                // the same seam that buried the message composer.
                if (present.length >= 2)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      4,
                      16,
                      12 +
                          (ref.watch(liveBlockProvider) != null
                              ? ShellMetrics.liveStripHeight
                              : 0),
                    ),
                    child: Row(
                      children: [
                        if (result != null && !_kept) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => unawaited(_shuffle(present)),
                              child: const Text('Again'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => unawaited(_keep()),
                              child: const Text('Keep it'),
                            ),
                          ),
                        ] else
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _revealing
                                  ? null
                                  : () => unawaited(_shuffle(present)),
                              icon: const Icon(Icons.shuffle),
                              label: Text(
                                result == null ? 'Make groups' : 'Again',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (result == null && present.length >= 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Knows who is here and who has worked together.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.mode,
    required this.n,
    required this.remainder,
    required this.sizes,
    required this.onMode,
    required this.onN,
    required this.onRemainder,
  });

  final SplitMode mode;
  final int n;
  final RemainderPolicy remainder;
  final List<int> sizes;
  final ValueChanged<SplitMode> onMode;
  final ValueChanged<int> onN;
  final ValueChanged<RemainderPolicy> onRemainder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Groups of 3" and "3 groups" are different features, and one
        // number field silently picks one. Asking is the cheapest thing
        // that doubles the usefulness.
        SegmentedButton<SplitMode>(
          segments: const [
            ButtonSegment(
              value: SplitMode.groupsOf,
              label: Text('Groups of'),
            ),
            ButtonSegment(
              value: SplitMode.numberOfGroups,
              label: Text('Number of groups'),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onMode(s.first),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 2; i <= 6; i++)
              ChoiceChip(
                label: Text('$i'),
                selected: n == i,
                onSelected: (_) => onN(i),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          sizes.isEmpty ? '' : _plan(sizes),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        // The remainder policy IS the feature. 7 into pairs leaves one
        // child standing alone, and naming what happens to them is the
        // thing every other tool skips.
        Text(
          'Leftovers',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SegmentedButton<RemainderPolicy>(
          segments: const [
            ButtonSegment(
              value: RemainderPolicy.absorb,
              label: Text('Spread them'),
            ),
            ButtonSegment(
              value: RemainderPolicy.ownGroup,
              label: Text('Own group'),
            ),
            ButtonSegment(
              value: RemainderPolicy.sitOut,
              label: Text('Sit out'),
            ),
          ],
          selected: {remainder},
          onSelectionChanged: (s) => onRemainder(s.first),
        ),
        const SizedBox(height: 4),
        Text(
          switch (remainder) {
            RemainderPolicy.absorb =>
              'Nobody stands alone — the spare children join existing groups.',
            RemainderPolicy.ownGroup =>
              'The spare children become their own smaller group.',
            RemainderPolicy.sitOut =>
              'The spare children sit this one out — whoever has sat out '
                  'least, so it rotates.',
          },
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  String _plan(List<int> sizes) {
    final counts = <int, int>{};
    for (final s in sizes) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final parts = [
      for (final e in counts.entries)
        '${e.value} ${e.value == 1 ? 'group' : 'groups'} of ${e.key}',
    ];
    return parts.join(' · ');
  }
}

class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.result,
    required this.names,
    required this.kept,
  });

  final RotationResult result;
  final Map<String, String> names;
  final bool kept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repeatsByPair = {
      for (final r in result.repeats) '${r.a}|${r.b}': r.lastRound,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Report the MIX, not a warning. A count with no referent is an
        // alarm; this is information.
        Text(
          result.repeatPairs == 0
              ? '${result.newPairs} new '
                    '${result.newPairs == 1 ? 'pairing' : 'pairings'} · '
                    'nobody repeats'
              : '${result.newPairs} new · ${result.repeatPairs} unavoidable '
                    '${result.repeatPairs == 1 ? 'repeat' : 'repeats'}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < result.groups.length; i++)
          _GroupCard(
            index: i,
            members: result.groups[i],
            names: names,
            repeatsByPair: repeatsByPair,
          ),
        if (result.satOut.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Sitting out: '
            '${result.satOut.map((id) => names[id] ?? '?').join(', ')}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (kept) ...[
          const SizedBox(height: 10),
          Text(
            'Kept. Next time the app will remember these pairs.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.index,
    required this.members,
    required this.names,
    required this.repeatsByPair,
  });

  final int index;
  final List<String> members;
  final Map<String, String> names;
  final Map<String, int> repeatsByPair;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Which pairs in THIS group are repeats, and when they last met.
    final notes = <String>[];
    for (var i = 0; i < members.length; i++) {
      for (var j = i + 1; j < members.length; j++) {
        final key = members[i].compareTo(members[j]) <= 0
            ? '${members[i]}|${members[j]}'
            : '${members[j]}|${members[i]}';
        final last = repeatsByPair[key];
        if (last != null) {
          notes.add(
            '${names[members[i]] ?? '?'} + ${names[members[j]] ?? '?'} '
            'were together in round $last',
          );
        }
      }
    }
    final hasRepeat = notes.isNotEmpty;

    // A new arrangement settles in rather than snapping, so the question
    // "what moved?" stays answerable.
    return TweenAnimationBuilder<double>(
      key: ValueKey('group-$index-${members.join()}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + index * 70),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(16 * (1 - t), 0),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: 2,
              color: hasRepeat
                  ? theme.colorScheme.tertiary
                  : theme.colorScheme.primary,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              members.map((id) => names[id] ?? '?').join(' · '),
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 1),
            Text(
              hasRepeat ? notes.first : 'all new to each other',
              style: theme.textTheme.bodySmall?.copyWith(
                color: hasRepeat
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
