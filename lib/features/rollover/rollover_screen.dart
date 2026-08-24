import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/rollover/rollover_plan.dart';
import 'package:differentworld/features/rollover/rollover_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Start a new year (docs/ROLLOVER.md).
///
/// The screen exists because the alternative was a delete. Everything here
/// is additive: a child either carries forward into a room or becomes an
/// alumnus who keeps every record they ever had. The count at the bottom
/// says `0 records deleted` because that is the promise the feature makes,
/// and a promise is worth more when it is printed on the button.
///
/// The default is deliberately "nobody changes": tap straight through and
/// only the period is new. Moving a child on has to be chosen.
class RolloverScreen extends ConsumerStatefulWidget {
  const RolloverScreen({super.key});

  @override
  ConsumerState<RolloverScreen> createState() => _RolloverScreenState();
}

class _RolloverScreenState extends ConsumerState<RolloverScreen> {
  final _name = TextEditingController();
  Map<String, RolloverChoice> _plan = const {};
  bool _seeded = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  List<RolloverCandidate> _candidates(List<Subject> roster) => [
    for (final s in roster)
      RolloverCandidate(
        subjectId: s.id,
        name: '${s.firstName} ${s.lastName}'.trim(),
        currentGroupId: s.groupId,
      ),
  ];

  Future<void> _start(List<RolloverCandidate> roster) async {
    final space = ref.read(viewerProvider).spaceId;
    if (space == null || _busy) return;
    final spaceId = space;
    final name = _name.text.trim();
    if (name.isEmpty) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    const uuid = Uuid();
    final now = DateTime.now().toIso8601String();
    final termId = uuid.v4();
    final summary = summarise(roster, _plan);
    // Captured BEFORE the write, because undo has to put this period back
    // as the current one. Null on the very first rollover, which undo
    // handles — there is simply no previous period to restore.
    final previousTermId = ref.read(currentTermProvider).value?.id;

    try {
      final db = await ref.read(appDatabaseProvider.future);
      await db.placementsDao.applyRollover(
        spaceId: spaceId,
        newTermId: termId,
        newTerm: TermsCompanion.insert(
          id: termId,
          spaceId: spaceId,
          name: name,
          startsOn: todayKey(),
          createdAt: now,
          updatedAt: now,
          isCurrent: const Value(1),
        ),
        returning: returningRooms(roster, _plan),
        newId: uuid.v4,
        nowIso: now,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            '$name started — ${summary.carriedForward} carried forward, '
            '${summary.becameAlumni} now alumni, '
            '${summary.recordsDeleted} records deleted.',
          ),
          // Undo is offered because it genuinely works: the rollover only
          // ever wrote, so putting it back is a matter of closing what it
          // opened and re-opening what it closed.
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => unawaited(
              _undo(
                spaceId: spaceId,
                termId: termId,
                previousTermId: previousTermId,
              ),
            ),
          ),
        ),
      );
      navigator.pop();
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'rollover'),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't start the year. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Put the year back. Safe to offer because nothing was destroyed.
  Future<void> _undo({
    required String spaceId,
    required String termId,
    required String? previousTermId,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final db = await ref.read(appDatabaseProvider.future);
      await db.placementsDao.undoRollover(
        spaceId: spaceId,
        termId: termId,
        previousTermId: previousTermId,
        nowIso: DateTime.now().toIso8601String(),
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text('Put back. Nothing changed.')),
      );
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'rollover'),
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text("Couldn't undo that. Try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);
    final roster =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final candidates = _candidates(roster);

    if (!_seeded && candidates.isNotEmpty) {
      _seeded = true;
      _plan = defaultPlan(candidates);
      // Suggest the next period's name from the current one, so the common
      // case is one tap rather than one more thing to word.
      final current = ref.read(currentTermProvider).value;
      _name.text = suggestTermName(current?.name, DateTime.now());
    }

    final summary = summarise(candidates, _plan);
    final byGroup = <String?, List<RolloverCandidate>>{};
    for (final c in candidates) {
      byGroup.putIfAbsent(c.currentGroupId, () => []).add(c);
    }

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        PrimaryActionButton(
          tooltip: 'Start the year',
          icon: Icons.check,
          onPressed: (_busy || candidates.isEmpty)
              ? null
              : () => unawaited(_start(candidates)),
        ),
      ],
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const ContentHeader(
                  title: 'Start a new year',
                  subtitle: 'Nothing is deleted. Everyone keeps their book.',
                ),
                if (candidates.isEmpty)
                  EmptyState(
                    icon: Icons.groups_outlined,
                    title: 'Nobody enrolled yet',
                    message:
                        'Add ${labels.subjectPlural.toLowerCase()} first — '
                        'a year rollover moves the children you already have.',
                  )
                else ...[
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Call it',
                      hintText: '2026–27',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  for (final entry in byGroup.entries) ...[
                    Text(
                      groups
                              .where((g) => g.id == entry.key)
                              .map((g) => g.name)
                              .firstOrNull ??
                          'No ${labels.group.toLowerCase()}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    for (final c in entry.value)
                      _CandidateRow(
                        candidate: c,
                        groups: groups,
                        choice: _plan[c.subjectId],
                        onChanged: (next) => setState(
                          () => _plan = {..._plan, c.subjectId: next},
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    '${summary.carriedForward} carry forward · '
                    '${summary.becameAlumni} become alumni',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${summary.recordsDeleted} records deleted · '
                    'every past ${labels.subject.toLowerCase()} keeps their '
                    'photos, notes and book.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({
    required this.candidate,
    required this.groups,
    required this.choice,
    required this.onChanged,
  });

  final RolloverCandidate candidate;
  final List<Group> groups;
  final RolloverChoice? choice;
  final ValueChanged<RolloverChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolved =
        choice ??
        RolloverChoice(
          fate: Fate.carriesForward,
          groupId: candidate.currentGroupId,
        );
    final leaving = !resolved.carries;
    final destination = groups
        .where((g) => g.id == resolved.groupId)
        .map((g) => g.name)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            width: 2,
            color: leaving
                ? theme.colorScheme.tertiary
                : theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(candidate.name, style: theme.textTheme.bodyLarge),
                Text(
                  leaving
                      ? 'moving on — keeps everything'
                      : destination == null
                      ? 'no room yet'
                      : 'into $destination',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: leaving
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Where they go',
            onSelected: (value) => onChanged(
              value == '_alumni'
                  ? const RolloverChoice(fate: Fate.becomesAlumni)
                  : RolloverChoice(
                      fate: Fate.carriesForward,
                      groupId: value == '_none' ? null : value,
                    ),
            ),
            itemBuilder: (_) => [
              for (final g in groups)
                PopupMenuItem(value: g.id, child: Text(g.name)),
              const PopupMenuItem(value: '_none', child: Text('No room yet')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: '_alumni', child: Text('Alumni')),
            ],
            child: Chip(
              label: Text(
                leaving ? 'Alumni' : destination ?? 'No room',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
