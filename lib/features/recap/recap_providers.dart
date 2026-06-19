import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/daily/daily_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/heroes/hero_catalog.dart';
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

      final sorted = [...blocks]..sort((a, b) => a.startAt.compareTo(b.startAt));
      final activities = <String>[];
      for (final b in sorted) {
        final name = labelFor(b);
        if (!activities.contains(name)) activities.add(name);
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
          ),
        );
      }

      return RecapDraft(
        activities: activities,
        question: question,
        children: children,
      );
    });
