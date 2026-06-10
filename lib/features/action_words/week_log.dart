import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The teacher's end-of-week log for a child (docs/WORLD.md) — the
/// human-noticed bits (milestone / spell learned / ally) that the derived
/// data (verbs / world / inventory) can't capture. One per (subject, week).
@immutable
class WeekLog {
  const WeekLog({
    required this.week,
    this.milestone = '',
    this.spell = '',
    this.ally = '',
  });

  factory WeekLog.fromEntry(Entry e) {
    Map<String, dynamic> d;
    try {
      final decoded = jsonDecode(e.details);
      d = decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      d = const {};
    }
    return WeekLog(
      week: (d['week'] as num?)?.toInt() ?? 0,
      milestone: (d['milestone'] as String?) ?? '',
      spell: (d['spell'] as String?) ?? '',
      ally: (d['ally'] as String?) ?? '',
    );
  }

  final int week;
  final String milestone;
  final String spell;
  final String ally;

  bool get isEmpty => milestone.isEmpty && spell.isEmpty && ally.isEmpty;
}

/// The log for one (subject's entries, week), or null if none yet.
WeekLog? weekLogFor(List<Entry> entries, int week) {
  for (final e in entries) {
    if (e.kind != EntryKind.weekLog) continue;
    final log = WeekLog.fromEntry(e);
    if (log.week == week) return log;
  }
  return null;
}

/// Open the week-log editor for (subject, week).
Future<void> showWeekLogSheet(
  BuildContext context, {
  required String subjectId,
  required String firstName,
  required int week,
  String? groupId,
}) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _WeekLogSheet(
      subjectId: subjectId,
      firstName: firstName,
      week: week,
      groupId: groupId,
    ),
  );
}

class _WeekLogSheet extends ConsumerStatefulWidget {
  const _WeekLogSheet({
    required this.subjectId,
    required this.firstName,
    required this.week,
    required this.groupId,
  });

  final String subjectId;
  final String firstName;
  final int week;
  final String? groupId;

  @override
  ConsumerState<_WeekLogSheet> createState() => _WeekLogSheetState();
}

class _WeekLogSheetState extends ConsumerState<_WeekLogSheet> {
  final _milestone = TextEditingController();
  final _spell = TextEditingController();
  final _ally = TextEditingController();
  bool _loaded = false;
  // Baseline = what was loaded (or empty for a new log). Dirty = any field
  // diverged. `_closing` short-circuits the guard once Save has fired so the
  // programmatic pop doesn't trip the discard dialog.
  String _baseMilestone = '';
  String _baseSpell = '';
  String _baseAlly = '';
  bool _closing = false;

  bool _isDirty() =>
      !_closing &&
      (_milestone.text != _baseMilestone ||
          _spell.text != _baseSpell ||
          _ally.text != _baseAlly);

  @override
  void dispose() {
    _milestone.dispose();
    _spell.dispose();
    _ally.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Prefill from the existing log once it has actually LOADED. Gate on
    // hasValue (not the `?? []` fallback) so a cold/loading stream frame
    // doesn't lock an empty baseline + skip the real log — which would open
    // an existing week's sheet blank and treat the empty form as clean.
    final logsAsync = ref.watch(
      entriesForSubjectProvider(
        (subjectId: widget.subjectId, kind: EntryKind.weekLog),
      ),
    );
    if (!_loaded && logsAsync.hasValue) {
      final existing = weekLogFor(logsAsync.requireValue, widget.week);
      if (existing != null) {
        _milestone.text = existing.milestone;
        _spell.text = existing.spell;
        _ally.text = existing.ally;
      }
      _baseMilestone = _milestone.text;
      _baseSpell = _spell.text;
      _baseAlly = _ally.text;
      _loaded = true;
    }

    return DismissGuard(
      isDirty: _isDirty,
      discardMessage: 'You have unsaved notes for this week. Discard them?',
      child: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.firstName} · Week ${widget.week} log',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 14),
                _Field(
                  controller: _milestone,
                  label: 'Milestone',
                  hint: 'held still for 2 minutes watching a bug',
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _spell,
                  label: 'Spell learned',
                  hint: 'CANOPY',
                ),
                const SizedBox(height: 12),
                _Field(
                  controller: _ally,
                  label: 'Ally',
                  hint: 'worked with Sofia on the sound map',
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await ref
                        .read(entryActionsProvider)
                        .setWeekLog(
                          subjectId: widget.subjectId,
                          week: widget.week,
                          groupId: widget.groupId,
                          milestone: _milestone.text,
                          spell: _spell.text,
                          ally: _ally.text,
                        );
                    if (!mounted) return;
                    _closing = true; // saved → let the guard pass on pop
                    nav.pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
  });
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
