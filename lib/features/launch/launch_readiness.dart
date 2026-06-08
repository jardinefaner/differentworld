import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/schedule/day_template_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a readiness item stands.
enum ReadyStatus {
  /// Done — a real precondition is satisfied.
  done,

  /// Not yet — blocks a smooth day; carries a fix action.
  todo,

  /// A reminder (e.g. "print the cards") the app can't verify — a nudge.
  info,
}

/// One line in the "ready to run tomorrow" check.
@immutable
class ReadyItem {
  const ReadyItem({
    required this.id,
    required this.status,
    required this.title,
    required this.why,
    this.actionLabel,
    this.actionRoute,
  });

  final String id;
  final ReadyStatus status;
  final String title;
  final String why;
  final String? actionLabel;
  final String? actionRoute;

  /// Counts toward "ready" — info reminders don't gate readiness.
  bool get gating => status != ReadyStatus.info;
}

/// Build the readiness list from the booleans the app can actually check. Pure
/// + testable; the provider feeds it real state.
List<ReadyItem> buildReadiness({
  required bool worldLive,
  required bool hasKids,
  required bool hasPlan,
  String? worldName,
  int? week,
}) {
  return [
    ReadyItem(
      id: 'journey',
      status: worldLive ? ReadyStatus.done : ReadyStatus.todo,
      title: worldLive
          ? "This week's world is live"
          : 'Set the journey start date',
      why: worldLive
          ? '${worldName ?? ''}${week != null ? ' · Week $week' : ''}'
          : 'Without a start date no world is live — the whole curriculum '
                'hangs off it. One tap, once.',
      actionLabel: worldLive ? null : 'Set it up',
      actionRoute: '/this-week',
    ),
    ReadyItem(
      id: 'roster',
      status: hasKids ? ReadyStatus.done : ReadyStatus.todo,
      title: hasKids ? 'Children are enrolled' : 'Add your children',
      why: 'The roster is who you pick verbs for, log, and reveal at closing.',
      actionLabel: hasKids ? null : 'Add children',
      actionRoute: '/',
    ),
    ReadyItem(
      id: 'plan',
      status: hasPlan ? ReadyStatus.done : ReadyStatus.todo,
      title: hasPlan ? 'The day has a shape' : 'Shape the day',
      why:
          'A day template gives the day its blocks and rhythm — drag the '
          'durations, the times fall out.',
      actionLabel: hasPlan ? null : 'Build a day',
      actionRoute: '/schedule/day-templates',
    ),
    const ReadyItem(
      id: 'cards',
      status: ReadyStatus.info,
      title: 'Print the morning basket',
      why:
          'The 12 verb cards + the timer spells. Laminate tonight; they '
          "last all summer. (The app can't see your printer.)",
      actionLabel: 'Open the toolkit',
      actionRoute: '/print',
    ),
  ];
}

/// Are the gating items all done?
bool allReady(List<ReadyItem> items) =>
    items.where((i) => i.gating).every((i) => i.status == ReadyStatus.done);

/// (done, total) over the gating items — drives "2 / 3 ready".
({int done, int total}) readyCount(List<ReadyItem> items) {
  final gating = items.where((i) => i.gating).toList();
  return (
    done: gating.where((i) => i.status == ReadyStatus.done).length,
    total: gating.length,
  );
}

/// The live readiness check — composed from the real preconditions.
final launchReadinessProvider = Provider<List<ReadyItem>>((ref) {
  final world = ref.watch(currentWorldProvider);
  final kids = ref.watch(subjectsInSpaceProvider).value ?? const [];
  final plans = ref.watch(dayTemplatesProvider);
  return buildReadiness(
    worldLive: world != null,
    worldName: world?.name,
    week: world?.week,
    hasKids: kids.isNotEmpty,
    hasPlan: plans.isNotEmpty,
  );
});
