import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';

/// Pure helpers for the mission do-it + save-progress loop (docs/MISSIONS.md
/// slice 2). A completion is an `entries` row (kind 'mission'); these encode
/// its details and read the track record back, unit-testable without a DB.

/// Encode the `details` JSON for a mission-completion entry.
String encodeMissionCompletion({
  required String missionId,
  required String missionName,
  required int stepsDone,
  required int stepsTotal,
  String? builds,
}) => jsonEncode({
  'missionId': missionId,
  'missionName': missionName,
  if (builds != null && builds.isNotEmpty) 'builds': builds,
  'stepsDone': stepsDone,
  'stepsTotal': stepsTotal,
});

/// Count completions per `missionId` from mission-kind entries. Tolerant of
/// malformed / legacy rows (skipped).
Map<String, int> missionCompletionCounts(List<Entry> entries) {
  final counts = <String, int>{};
  for (final e in entries) {
    final id = _missionIdOf(e.details);
    if (id != null) counts[id] = (counts[id] ?? 0) + 1;
  }
  return counts;
}

String? _missionIdOf(String detailsJson) {
  try {
    final decoded = jsonDecode(detailsJson);
    if (decoded is Map && decoded['missionId'] is String) {
      return decoded['missionId'] as String;
    }
  } on FormatException {
    // skip malformed
  }
  return null;
}
