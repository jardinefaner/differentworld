import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One reflection, parsed from its [Entry] — the honest stopwatch [seconds],
/// the how-did-it-go [face] (1–4), and the optional [note]. The growth strip
/// reads these; the raw row stays an entry so it also flows into the Book.
class ReflectionView {
  const ReflectionView({
    required this.entry,
    required this.seconds,
    required this.face,
    this.note,
  });

  /// Parse an `entries` row of kind `reflection`. Malformed JSON degrades to
  /// zeros rather than throwing — a reflection should never crash the strip.
  factory ReflectionView.of(Entry e) {
    var seconds = 0;
    var face = 0;
    try {
      final decoded = jsonDecode(e.details);
      if (decoded is Map) {
        seconds = (decoded['seconds'] as num?)?.toInt() ?? 0;
        face = (decoded['face'] as num?)?.toInt() ?? 0;
      }
    } on Object {
      // malformed details → zeros
    }
    final body = e.body?.trim();
    return ReflectionView(
      entry: e,
      seconds: seconds,
      face: face,
      note: (body == null || body.isEmpty) ? null : body,
    );
  }

  final Entry entry;
  final int seconds;
  final int face;
  final String? note;
}

/// The program's reflections, newest first — the visible, accumulating growth
/// record. Space-scoped (every reflection the viewer's program holds). Offline-
/// first: a Drift watch over the local `entries` table.
// autoDispose stream providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final recentReflectionsProvider =
    StreamProvider.autoDispose<List<ReflectionView>>((ref) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      final spaceId = ref.watch(viewerProvider).spaceId;
      if (spaceId == null) {
        yield const [];
        return;
      }
      yield* db.entriesDao
          .watchInSpace(spaceId: spaceId, kind: EntryKind.reflection)
          .map((rows) => rows.map(ReflectionView.of).toList(growable: false));
    });
