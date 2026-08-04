import 'dart:async';
import 'dart:math';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/picker/picker_logic.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `/picker` — the fair name picker. Pick one kid, a pair, or split the
/// room into teams; **everyone gets picked before anyone repeats** (the
/// FairBag in picker_logic.dart, persisted per room across restarts).
/// "Here today" narrows the bag to kids marked present/late once
/// attendance has been taken. A standalone tool — deliberately NOT a
/// brain break.
class NamePickerScreen extends ConsumerStatefulWidget {
  const NamePickerScreen({super.key});

  @override
  ConsumerState<NamePickerScreen> createState() => _NamePickerScreenState();
}

enum _Mode { one, two, teams }

class _NamePickerScreenState extends ConsumerState<NamePickerScreen> {
  final Random _rng = Random();
  String? _groupId;
  _Mode _mode = _Mode.one;
  bool _hereToday = true;
  int _teamCount = 2;

  /// The current reveal (ids), newest draw.
  List<String> _lastDrawn = const [];
  bool _freshRound = false;
  List<List<String>>? _teams;
  FairBag? _bag;

  String get _prefsKey => 'picker.bag.$_groupId';

  Future<void> _loadBag() async {
    if (_groupId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (!mounted) return;
    setState(() {
      _bag = raw == null
          ? const FairBag(remaining: [], picked: [])
          : FairBag.fromJson(raw);
      _lastDrawn = const [];
      _teams = null;
      _freshRound = false;
    });
  }

  Future<void> _saveBag(FairBag bag) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, bag.toJson());
  }

  void _pick(List<String> eligible) {
    final synced = (_bag ?? const FairBag(remaining: [], picked: []))
        .syncedWith(eligible, _rng);
    final seeded = synced.remaining.isEmpty && synced.picked.isEmpty
        ? FairBag.fresh(eligible, _rng)
        : synced;
    final n = _mode == _Mode.two ? 2 : 1;
    final result = seeded.draw(n, eligible, _rng);
    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _bag = result.bag;
      _lastDrawn = result.drawn;
      _freshRound = result.refilled;
      _teams = null;
    });
    unawaited(_saveBag(result.bag));
  }

  void _reset(List<String> eligible) {
    final fresh = FairBag.fresh(eligible, _rng);
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _bag = fresh;
      _lastDrawn = const [];
      _freshRound = false;
      _teams = null;
    });
    unawaited(_saveBag(fresh));
  }

  void _shuffleTeams(List<String> eligible) {
    unawaited(HapticFeedback.mediumImpact());
    setState(() => _teams = splitTeams(eligible, _teamCount, _rng));
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    if (viewer is GuardianViewer || !viewer.isSignedIn) {
      return const EdgeScaffold(
        body: NoAccess(title: 'The picker lives on the staff side.'),
      );
    }
    final groupsAsync = ref.watch(groupsProvider);
    return EdgeScaffold(
      body: groupsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const EmptyState(
          icon: Icons.casino_outlined,
          title: 'Could not load rooms',
          message: 'Try again in a moment.',
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return const EmptyState(
              icon: Icons.casino_outlined,
              title: 'No rooms yet',
              message: 'Add a room and its kids, then come pick names.',
            );
          }
          final groupId = _groupId ?? groups.first.id;
          if (_groupId == null) {
            _groupId = groupId;
            unawaited(_loadBag());
          }
          return _body(groups, groupId);
        },
      ),
    );
  }

  Widget _body(List<Group> groups, String groupId) {
    final theme = Theme.of(context);
    final subjects =
        ref.watch(subjectsInGroupProvider(groupId)).value ?? const <Subject>[];
    final attendance =
        ref
            .watch(
              attendanceForDayProvider((groupId: groupId, date: todayKey())),
            )
            .value ??
        const <AttendanceRecord>[];
    final hereIds = {
      for (final r in attendance)
        if (AttendanceStatus.fromDb(r.status) == AttendanceStatus.present ||
            AttendanceStatus.fromDb(r.status) == AttendanceStatus.late)
          r.subjectId,
    };
    final attendanceTaken = attendance.isNotEmpty;
    final useHere = _hereToday && attendanceTaken;
    final eligible = [
      for (final s in subjects)
        if (!useHere || hereIds.contains(s.id)) s.id,
    ];
    final byId = {for (final s in subjects) s.id: s};
    final bag = (_bag ?? const FairBag(remaining: [], picked: [])).syncedWith(
      eligible,
      _rng,
    );
    final pickedCount = bag.picked.length;

    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'Pick me',
          subtitle: 'Fair turns — everyone goes before anyone repeats.',
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final g in groups) ...[
                ChoiceChip(
                  label: Text(g.name),
                  selected: groupId == g.id,
                  onSelected: (_) {
                    setState(() {
                      _groupId = g.id;
                      _bag = null;
                      _teams = null;
                      _lastDrawn = const [];
                    });
                    unawaited(_loadBag());
                  },
                ),
                const SizedBox(width: 6),
              ],
              if (attendanceTaken)
                FilterChip(
                  label: const Text('Here today'),
                  selected: _hereToday,
                  onSelected: (v) => setState(() => _hereToday = v),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_Mode>(
          segments: const [
            ButtonSegment(value: _Mode.one, label: Text('One')),
            ButtonSegment(value: _Mode.two, label: Text('Two')),
            ButtonSegment(value: _Mode.teams, label: Text('Teams')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 14),
        if (eligible.isEmpty)
          EmptyState(
            icon: Icons.casino_outlined,
            title: useHere ? 'Nobody marked here yet' : 'No kids in this room',
            message: useHere
                ? 'Take attendance first, or turn off "Here today" to '
                      'pick from the full roster.'
                : 'Add kids to this room to start picking.',
          )
        else if (_mode == _Mode.teams)
          _teamsView(theme, eligible, byId)
        else
          _drawView(theme, eligible, byId, bag, pickedCount),
      ],
    );
  }

  Widget _drawView(
    ThemeData theme,
    List<String> eligible,
    Map<String, Subject> byId,
    FairBag bag,
    int pickedCount,
  ) {
    final names = [
      for (final id in _lastDrawn) byId[id]?.firstName ?? 'Someone',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 3),
            ),
          ),
          child: Column(
            children: [
              Text(
                _freshRound ? "FRESH ROUND — EVERYONE'S BACK IN" : 'NEXT UP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                names.isEmpty ? '—' : names.join('  &  '),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall,
              ),
              const SizedBox(height: 8),
              Text(
                '$pickedCount of ${eligible.length} picked this round',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _pick(eligible),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.casino_outlined),
                label: Text(
                  _mode == _Mode.two ? 'Pick two names' : 'Pick the next name',
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.outlined(
              tooltip: 'Start a fresh round',
              onPressed: () => _reset(eligible),
              icon: const Icon(Icons.replay),
            ),
          ],
        ),
        if (bag.picked.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Already picked',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in bag.picked)
                Chip(
                  label: Text(byId[id]?.firstName ?? 'Someone'),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _teamsView(
    ThemeData theme,
    List<String> eligible,
    Map<String, Subject> byId,
  ) {
    final teams = _teams;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Teams', style: theme.textTheme.bodyMedium),
            const SizedBox(width: 10),
            for (var n = 2; n <= 6; n++) ...[
              ChoiceChip(
                label: Text('$n'),
                selected: _teamCount == n,
                onSelected: (_) => setState(() {
                  _teamCount = n;
                  _teams = null;
                }),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _shuffleTeams(eligible),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.groups_outlined),
          label: Text(teams == null ? 'Make the teams' : 'Shuffle again'),
        ),
        if (teams != null) ...[
          const SizedBox(height: 14),
          for (var t = 0; t < teams.length; t++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                border: Border(
                  left: BorderSide(color: theme.colorScheme.primary, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Team ${t + 1} — ${kTeamNames[t % kTeamNames.length]}',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      for (final id in teams[t]) byId[id]?.firstName ?? '?',
                    ].join(' · '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
