import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/verb_skills.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A measurable SKILL — the RPG "stats that grow" (docs/VISION.md synthesis).
/// The skill is never TAUGHT; it's NOTICED. You time it, count it, measure it
/// inside the activities that already happen — and the rising number is the
/// proof a brain grew. The character sheet shows the latest value + the delta.
@immutable
class MeasurableSkill {
  const MeasurableSkill({
    required this.id,
    required this.emoji,
    required this.label,
    required this.unit,
    required this.hint,
  });

  final String id;
  final String emoji;
  final String label;

  /// The display suffix ("s", "arm-spans", "words", "details", "/5").
  final String unit;

  /// How to take the measurement (shown in the capture sheet).
  final String hint;

  String format(num v) {
    final n = v % 1 == 0 ? v.toInt().toString() : v.toString();
    return switch (unit) {
      's' => '${n}s',
      '/5' => '$n/5',
      '/day' => '$n/day',
      '' => n,
      _ => '$n $unit',
    };
  }
}

/// The display suffix for a [VerbSkill]'s measure — how the number reads on the
/// character sheet ('90s', '4/5', '3/day', '12').
String skillUnitFor(SkillMeasureKind measure) => switch (measure) {
  SkillMeasureKind.seconds => 's',
  SkillMeasureKind.rating => '/5',
  SkillMeasureKind.frequency => '/day',
  SkillMeasureKind.count => '',
};

/// The measurable skills — DERIVED from the canonical 60-skill catalog
/// (`kVerbSkills`), so the character sheet + the log sheet render the same
/// skills the whole app knows about. `MeasurableSkill` stays the display shape
/// (emoji from the verb, label = the one-word name, unit from the measure, hint
/// = the "how"); the source of truth is `verb_skills.dart`.
final List<MeasurableSkill> kMeasurableSkills = [
  for (final s in kVerbSkills)
    MeasurableSkill(
      id: s.id,
      emoji: verbById(s.verbId)?.emoji ?? '•',
      label: s.name,
      unit: skillUnitFor(s.measure),
      hint: s.how,
    ),
];

final Map<String, MeasurableSkill> _measurableById = {
  for (final s in kMeasurableSkills) s.id: s,
};

MeasurableSkill? measurableSkillById(String id) => _measurableById[id];

/// One recorded measurement.
@immutable
class SkillMeasure {
  const SkillMeasure({
    required this.skillId,
    required this.value,
    required this.at,
  });

  static SkillMeasure? fromEntry(Entry e) {
    if (e.kind != EntryKind.skillMeasure) return null;
    Map<String, dynamic> d;
    try {
      final decoded = jsonDecode(e.details);
      d = decoded is Map<String, dynamic> ? decoded : const {};
    } on FormatException {
      return null;
    }
    final skill = d['skill'] as String?;
    final value = d['value'] as num?;
    if (skill == null || value == null) return null;
    return SkillMeasure(
      skillId: skill,
      value: value,
      at:
          DateTime.tryParse(e.recordedAt) ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String skillId;
  final num value;
  final DateTime at;
}

/// Per skill, the latest value and the one before it (for the delta arrow).
typedef SkillProgress = ({num latest, num? previous});

Map<String, SkillProgress> latestSkillValues(List<Entry> entries) {
  // Oldest → newest, so the last two we see per skill are previous, latest.
  final bySkill = <String, List<SkillMeasure>>{};
  for (final e in entries) {
    final m = SkillMeasure.fromEntry(e);
    if (m != null) bySkill.putIfAbsent(m.skillId, () => []).add(m);
  }
  final out = <String, SkillProgress>{};
  for (final entry in bySkill.entries) {
    final list = entry.value..sort((a, b) => a.at.compareTo(b.at));
    out[entry.key] = (
      latest: list.last.value,
      previous: list.length >= 2 ? list[list.length - 2].value : null,
    );
  }
  return out;
}

/// Open the quick capture sheet to log a measurement for a child.
Future<void> showSkillMeasureSheet(
  BuildContext context, {
  required String subjectId,
  required String firstName,
  String? groupId,
}) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SkillMeasureSheet(
      subjectId: subjectId,
      firstName: firstName,
      groupId: groupId,
    ),
  );
}

class _SkillMeasureSheet extends ConsumerStatefulWidget {
  const _SkillMeasureSheet({
    required this.subjectId,
    required this.firstName,
    required this.groupId,
  });

  final String subjectId;
  final String firstName;
  final String? groupId;

  @override
  ConsumerState<_SkillMeasureSheet> createState() => _SkillMeasureSheetState();
}

class _SkillMeasureSheetState extends ConsumerState<_SkillMeasureSheet> {
  String _verbId = kVerbs.first.id;
  String _skillId = kVerbSkills.first.id;
  final _value = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  bool get _isDirty => _value.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    final parsed = num.tryParse(_value.text.trim());
    if (parsed == null) {
      // Don't let Save be a silent no-op — say why nothing happened.
      setState(() => _error = 'Enter a number');
      return;
    }
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    await ref
        .read(entryActionsProvider)
        .recordSkillMeasure(
          subjectId: widget.subjectId,
          skillId: _skillId,
          value: parsed,
          groupId: widget.groupId,
        );
    if (!mounted) return;
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vs = verbSkillById(_skillId) ?? kVerbSkills.first;
    return DismissGuard(
      isDirty: () => _isDirty && !_saving,
      discardMessage: 'Discard this measurement?',
      child: SafeArea(
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
                'Measure ${widget.firstName}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'The verb, then the skill under it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              // The verb (what you do) …
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in kVerbs)
                    ChoiceChip(
                      label: Text('${v.emoji} ${v.label}'),
                      selected: v.id == _verbId,
                      showCheckmark: false,
                      onSelected: (_) => setState(() {
                        _verbId = v.id;
                        _skillId = skillsForVerb(v.id).first.id;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // … then the skill under it (how well).
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in skillsForVerb(_verbId))
                    ChoiceChip(
                      label: Text(s.name),
                      selected: s.id == _skillId,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _skillId = s.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                vs.how,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'week 1: ${vs.week1}  →  week 10: ${vs.week10}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _value,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                autofocus: true,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Value',
                  errorText: _error,
                  suffixText: switch (vs.measure) {
                    SkillMeasureKind.rating => 'out of 5',
                    SkillMeasureKind.seconds => 'seconds',
                    SkillMeasureKind.frequency => 'per day',
                    SkillMeasureKind.count => '',
                  },
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save measurement'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
