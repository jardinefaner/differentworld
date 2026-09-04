import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/summer_book.dart'
    show scrubOtherNames;
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// One made-thing in the week, reduced to what a slide needs.
typedef WrapItem = ({String day, String? imagePath, String body});

/// The **weekly wrap** — the first slice of the growth-showcase (docs/VISION.md:
/// every artifact a child makes compiles into a growth story). Auto-builds a
/// deck from the child's cumulative WORK over the last 7 days (the trail) and
/// casts it through the shared present engine: a title card, one slide per
/// made-thing (a snapped/drawn photo as the hero, or a typed note), and a
/// closing "and counting". No render pipeline — it rides the live cast spine,
/// so it's instant.
///
/// FAMILY-SAFE by construction: it shows only THIS child's own made things, and
/// any caption is run through [scrubOtherNames] so another enrolled child's name
/// can't leak into this child's keepsake (the family-scrub class, CLAUDE.md) —
/// the same guarantee the Summer Book gives. Safe to cast to the room AND (next
/// slice) to send home. The scrub + assembly is the pure, unit-tested
/// [buildWeeklyWrapSlides]; this function just gathers the data.
Future<void> castWeeklyWrap(
  BuildContext context,
  WidgetRef ref, {
  required String subjectId,
  required String childName,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);

  // The child's made-things, oldest->newest so the week reads as an arc.
  final all = await ref.read(
    entriesForSubjectProvider(
      (subjectId: subjectId, kind: EntryKind.workSample),
    ).future,
  );
  final weekAgo = DateTime.now().subtract(const Duration(days: 7));
  final week = all.where((e) {
    final at = DateTime.tryParse(e.recordedAt)?.toLocal();
    return at != null && at.isAfter(weekAgo);
  }).toList()..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

  if (week.isEmpty) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text('$childName hasn’t made anything this week yet.'),
      ),
    );
    return;
  }

  // Every OTHER enrolled child's name — scrubbed from captions (family-safe).
  final others = (ref.read(subjectsInSpaceProvider).value ?? const <Subject>[])
      .where((s) => s.id != subjectId)
      .expand((s) => [s.firstName, s.lastName])
      .map((n) => n.trim())
      .where((n) => n.isNotEmpty)
      .toSet();

  // Gather the body items, capped so a prolific week stays a HIGHLIGHT reel
  // (the growth-arc reel does the same); the lead count stays the full total.
  final items = <WrapItem>[];
  for (final e in week) {
    if (items.length >= 20) break;
    final atts = await ref.read(
      attachmentsForEntityProvider((kind: 'entry', id: e.id)).future,
    );
    final at = DateTime.tryParse(e.recordedAt)?.toLocal();
    final day = at == null ? '' : DateFormat.EEEE().format(at);
    final imagePath = atts.urls.isEmpty ? null : atts.urls.first;
    final body = (e.body ?? '').trim();
    if (imagePath != null || body.isNotEmpty) {
      items.add((day: day, imagePath: imagePath, body: body));
    }
  }

  if (!context.mounted) return;
  await presentSlides(
    context,
    title: '$childName’s week',
    slides: buildWeeklyWrapSlides(
      childName: childName,
      totalPieces: week.length,
      otherNames: others,
      items: items,
    ),
  );
}

/// Assemble the wrap's slides — PURE so it's unit-testable for the family-scrub
/// guarantee (test/unit/weekly_wrap_privacy_test.dart). Every caption is run
/// through [scrubOtherNames]; the subject's own name + the structured framing
/// stay. A photo item becomes a hero slide (the photo IS the slide, signed via
/// the present engine); a note-only item becomes a text slide of the child's
/// own (scrubbed) words.
List<PresentSlide> buildWeeklyWrapSlides({
  required String childName,
  required int totalPieces,
  required Set<String> otherNames,
  required List<WrapItem> items,
}) {
  final slides = <PresentSlide>[
    PresentSlide(
      eyebrow: 'This week',
      title: '$childName’s week',
      emoji: '🎞️',
      subtitle: totalPieces == 1 ? '1 piece' : '$totalPieces pieces',
    ),
  ];
  for (final it in items) {
    final note = scrubOtherNames(it.body.trim(), otherNames);
    if (it.imagePath != null) {
      slides.add(
        PresentSlide(eyebrow: it.day, title: note, imagePath: it.imagePath),
      );
    } else if (note.isNotEmpty) {
      slides.add(
        PresentSlide(eyebrow: it.day, title: note, icon: Icons.edit_note),
      );
    }
  }
  slides.add(
    PresentSlide(
      eyebrow: 'And counting',
      title: 'Look how much $childName made',
      emoji: '🌱',
    ),
  );
  return slides;
}
