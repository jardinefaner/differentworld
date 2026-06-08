import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
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
    return unit == 's' ? '${n}s' : (unit == '/5' ? '$n/5' : '$n $unit');
  }
}

/// The five things worth measuring (the RPG SKILLS list).
const kMeasurableSkills = <MeasurableSkill>[
  MeasurableSkill(
    id: 'stillness',
    emoji: '🧘',
    label: 'Stillness',
    unit: 's',
    hint: "How long can they hold still? Time it honestly — don't round up.",
  ),
  MeasurableSkill(
    id: 'story',
    emoji: '📜',
    label: 'Story length',
    unit: 'arm-spans',
    hint: 'The continuous story river — let the kid measure it in arm-spans.',
  ),
  MeasurableSkill(
    id: 'words',
    emoji: '✨',
    label: 'Beautiful words',
    unit: 'words',
    hint: "Fancy words used naturally in one sentence. Eavesdrop — don't quiz.",
  ),
  MeasurableSkill(
    id: 'details',
    emoji: '👀',
    label: 'Details noticed',
    unit: 'details',
    hint: 'Show a picture 30s, cover it — how many details can they name?',
  ),
  MeasurableSkill(
    id: 'depth',
    emoji: '💭',
    label: 'Answer depth',
    unit: '/5',
    hint:
        'How deep is a Wall answer? 1 = "a rock", 5 = "the way mom loves me".',
  ),
];

MeasurableSkill? measurableSkillById(String id) {
  for (final s in kMeasurableSkills) {
    if (s.id == id) return s;
  }
  return null;
}

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
  return showModalBottomSheet<void>(
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
  String _skillId = kMeasurableSkills.first.id;
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
    final skill = measurableSkillById(_skillId) ?? kMeasurableSkills.first;
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in kMeasurableSkills)
                    ChoiceChip(
                      label: Text('${s.emoji} ${s.label}'),
                      selected: s.id == _skillId,
                      onSelected: (_) => setState(() => _skillId = s.id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                skill.hint,
                style: theme.textTheme.bodySmall?.copyWith(
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
                  suffixText: skill.unit == '/5' ? 'out of 5' : skill.unit,
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
