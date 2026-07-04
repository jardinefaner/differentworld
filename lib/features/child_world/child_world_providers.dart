import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/child_world/child_world_model.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// (child, curriculum week) — the per-child weekly pieces are keyed on this.
typedef SubjectWeekKey = ({String subjectId, int week});

Map<String, dynamic>? _detailsForWeek(List<Entry> rows, int week) {
  for (final e in rows) {
    try {
      final d = jsonDecode(e.details);
      if (d is Map<String, dynamic> && (d['week'] as num?)?.toInt() == week) {
        return d;
      }
    } on FormatException {
      // skip a malformed row
    }
  }
  return null;
}

/// A child's **weekly intention** text for the week (null until they set one).
/// Drift-watched, so it's live + offline-first.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final weeklyIntentionProvider = StreamProvider.autoDispose
    .family<String?, SubjectWeekKey>((ref, key) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.entriesDao
          .watchForSubject(
            subjectId: key.subjectId,
            kind: EntryKind.weeklyIntention,
          )
          .map((rows) {
            final d = _detailsForWeek(rows, key.week);
            final t = (d?['text'] as String?)?.trim();
            return (t == null || t.isEmpty) ? null : t;
          });
    });

/// A child's **project** for the week (null until staff/child start one).
// ignore: specify_nonobvious_property_types
final childProjectProvider = StreamProvider.autoDispose
    .family<ProjectView?, SubjectWeekKey>((ref, key) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      yield* db.entriesDao
          .watchForSubject(subjectId: key.subjectId, kind: EntryKind.project)
          .map((rows) {
            final d = _detailsForWeek(rows, key.week);
            return d == null ? null : ProjectView.fromJson(d);
          });
    });

/// A child's **answer to today's daily prompt** (null until they answer). The
/// per-child half of the shared daily — "her own daily" is her response.
// ignore: specify_nonobvious_property_types
final todaysAnswerProvider = StreamProvider.autoDispose.family<String?, String>(
  (
    ref,
    subjectId,
  ) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    final today = todayKey();
    yield* db.entriesDao
        .watchForSubject(subjectId: subjectId, kind: EntryKind.dailyResponse)
        .map((rows) {
          for (final e in rows) {
            final created = DateTime.tryParse(e.recordedAt)?.toLocal();
            final body = e.body?.trim();
            if (created != null &&
                dateKey(created) == today &&
                body != null &&
                body.isNotEmpty) {
              return body;
            }
          }
          return null;
        });
  },
);
