import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One moment of the day in the **staff runbook** (docs/VISION.md "the adults
/// run on rails too"). The adult twin of "Play today": every moment carries
/// three lanes — what the LEAD does, what the HELPER does, and what to do IF
/// IT BREAKS (the contingency lane nobody writes down). So a new helper — or
/// a substitute who walked in cold — can run the next hour.
@immutable
class RunbookMoment {
  const RunbookMoment({
    required this.time,
    required this.name,
    required this.emoji,
    required this.lead,
    required this.helper,
    required this.ifItBreaks,
  });

  factory RunbookMoment.fromJson(Map<String, dynamic> j) => RunbookMoment(
    time: (j['time'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    emoji: (j['emoji'] as String?) ?? '•',
    lead: (j['lead'] as String?) ?? '',
    helper: (j['helper'] as String?) ?? '',
    ifItBreaks: (j['ifItBreaks'] as String?) ?? '',
  );

  final String time;
  final String name;
  final String emoji;

  /// What the LEAD teacher does this moment.
  final String lead;

  /// What the HELPER does this moment.
  final String helper;

  /// The contingency lane — what to do when this moment goes sideways.
  final String ifItBreaks;
}

/// The staff runbook, loaded once from the bundled JSON (offline-first).
final staffRunbookProvider = FutureProvider<List<RunbookMoment>>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/curriculum/staff_runbook.json',
  );
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const [];
  final moments = decoded['moments'];
  if (moments is! List) return const [];
  return [
    for (final m in moments)
      if (m is Map<String, dynamic>) RunbookMoment.fromJson(m),
  ];
});
