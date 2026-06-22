import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/daily/daily_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/heroes/hero_catalog.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/recap/recap_model.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// (cohort, day) — the key the composer assembles a draft for.
typedef RecapKey = ({String groupId, String date});

/// One room's assembled recap draft: the shared room facts + a per-child list
/// (already shaped as [RecapChildInput]) ready to hand straight to
/// `EntryActions.recordRecap` on Send.
class RecapDraft {
  const RecapDraft({
    required this.activities,
    required this.children,
    this.question,
  });

  /// The day's activities (deduped, in order) — from the room's schedule.
  final List<String> activities;

  /// The day's question, if the Daily is running.
  final String? question;

  /// One per child in the cohort, carrying their own moments (hero / answer).
  final List<RecapChildInput> children;

  /// How many children have at least one personal moment today.
  int get withMoments => children
      .where(
        (c) =>
            (c.heroName?.isNotEmpty ?? false) ||
            (c.answer?.isNotEmpty ?? false),
      )
      .length;

  /// Every distinct picture the day produced, for the STAFF preview — the union
  /// across children (room moments appear once; each child's own tagged photos
  /// are also surfaced so staff see the full day). De-duped, room-first by the
  /// order children were assembled. Family-side each child only ever sees their
  /// own scoped subset (see `RecapChildInput.photoUrls`).
  List<String> get photos {
    final seen = <String>{};
    final out = <String>[];
    for (final c in children) {
      for (final url in c.photoUrls) {
        if (seen.add(url)) out.add(url);
      }
    }
    return out;
  }
}

/// Assemble today's recap draft for a cohort: activities from the schedule, the
/// day's question from the Daily, and each child's own moments (their current
/// hero + their answer to today's question). One-shot reads at compose time —
/// the composer watches this, previews it, and Send passes `children` to
/// `recordRecap`. autoDispose so a closed composer doesn't keep the watch alive.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final recapDraftProvider = FutureProvider.autoDispose
    .family<RecapDraft, RecapKey>((ref, key) async {
      final db = await ref.watch(appDatabaseProvider.future);

      // Activities — the room's schedule for the day, in order, deduped.
      final blocks = await ref.watch(
        scheduleDayForGroupProvider((
          groupId: key.groupId,
          date: key.date,
        )).future,
      );
      final activityCatalog =
          ref.watch(activitiesProvider).value ?? const <Activity>[];
      String labelFor(ScheduleBlock b) {
        final t = b.title?.trim() ?? '';
        if (t.isNotEmpty) return t;
        if (b.activityId != null) {
          for (final a in activityCatalog) {
            if (a.id == b.activityId) return a.name;
          }
        }
        return 'Activity';
      }

      final sorted = [...blocks]
        ..sort((a, b) => a.startAt.compareTo(b.startAt));
      final activities = <String>[];
      for (final b in sorted) {
        final name = labelFor(b);
        if (!activities.contains(name)) activities.add(name);
      }

      // The day's pictures — gathered once across today's blocks, then split by
      // tag so each child's family sees the right set:
      //   • roomPhotos    — untagged block captures (subject_id null): the
      //                     ROOM's day, fine to show every family of the cohort.
      //   • taggedBySubject — photos tagged to a specific child: shown ONLY on
      //                     that child's family recap, never another's.
      // This is the privacy seam: a photo OF child A must not appear in child
      // B's keepsake (CLAUDE.md "don't broaden a child's card to show another
      // child's tagged photos"). De-duped by url across overlapping blocks.
      final roomPhotos = <String>[];
      final taggedBySubject = <String, List<String>>{};
      final seenUrls = <String>{};
      for (final b in sorted) {
        final shots = await ref.watch(attachmentsForBlockProvider(b.id).future);
        for (final a in shots) {
          // Skip a not-yet-uploaded photo: a `pending:<localpath>` token would
          // be stored verbatim in the family-facing recap entry and render as a
          // broken image on the parent's device (which can't see the local
          // bytes). It rejoins on a later send once the upload syncs.
          if (a.url.startsWith('pending:')) continue;
          if (!seenUrls.add(a.url)) continue;
          final sid = a.subjectId;
          if (sid == null || sid.isEmpty) {
            roomPhotos.add(a.url);
          } else {
            (taggedBySubject[sid] ??= <String>[]).add(a.url);
          }
        }
      }

      // The day's question (if the Daily is on).
      final question =
          ref.watch(todaysDailyProvider).question?.payload['text'] as String?;

      // Per child — their hero + today's answer.
      final roster = await ref.watch(
        subjectsInGroupProvider(key.groupId).future,
      );
      final children = <RecapChildInput>[];
      for (final s in roster) {
        final heroRows = await db.entriesDao
            .watchForSubject(
              subjectId: s.id,
              kind: EntryKind.hero,
              limit: 1,
            )
            .first;
        final heroName = heroRows.isEmpty
            ? null
            : HeroCardData.tryParse(heroRows.first.details)?.name;

        final answerRows = await db.entriesDao
            .watchForSubject(
              subjectId: s.id,
              kind: EntryKind.dailyResponse,
              limit: 30,
            )
            .first;
        String? answer;
        for (final e in answerRows) {
          final created = DateTime.tryParse(e.recordedAt)?.toLocal();
          final body = e.body?.trim();
          if (created != null &&
              dateKey(created) == key.date &&
              body != null &&
              body.isNotEmpty) {
            answer = body;
            break;
          }
        }

        children.add(
          RecapChildInput(
            subjectId: s.id,
            firstName: s.firstName,
            ownNames: <String>{
              s.firstName.trim(),
              s.lastName.trim(),
            }..removeWhere((n) => n.isEmpty),
            heroName: heroName,
            answer: answer,
            // Room moments + this child's OWN tagged photos — never another
            // child's. Room photos lead (the shared day) then the personal ones.
            photoUrls: [
              ...roomPhotos,
              ...?taggedBySubject[s.id],
            ],
          ),
        );
      }

      return RecapDraft(
        activities: activities,
        question: question,
        children: children,
      );
    });
