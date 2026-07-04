import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/senses.dart';
import 'package:differentworld/features/action_words/verbs.dart';

/// The Action Words verbs tagged on an activity (stored in the activity's
/// `capabilities.action_verbs` — no migration). Unknown ids are dropped.
List<String> activityVerbs(Activity a) {
  final raw =
      Capabilities.fromJson(
        a.capabilities,
      ).get<List<dynamic>>('action_verbs') ??
      const <dynamic>[];
  return [
    for (final e in raw)
      if (verbById(e.toString()) != null) e.toString(),
  ];
}

/// The senses an activity engages (stored in `capabilities.senses` — the
/// sensory facet). Unknown values are dropped.
List<Sense> activitySenses(Activity a) {
  final raw =
      Capabilities.fromJson(a.capabilities).get<List<dynamic>>('senses') ??
      const <dynamic>[];
  final out = <Sense>[];
  for (final e in raw) {
    for (final s in Sense.values) {
      if (s.name == e.toString()) {
        out.add(s);
        break;
      }
    }
  }
  return out;
}

/// An activity paired with how many of the kid's picked verbs it shares.
class ActivityMatch {
  const ActivityMatch({required this.activity, required this.overlap});

  final Activity activity;
  final int overlap;
}

/// Activities matching a kid's [picks] — at least one shared verb, best
/// overlap first (so 3- and 2-verb matches lead). Archived activities are
/// excluded. The brief's activity matcher.
List<ActivityMatch> matchActivities(
  Set<String> picks,
  List<Activity> activities,
) {
  final out = <ActivityMatch>[];
  for (final a in activities) {
    if (a.archivedAt != null) continue;
    final overlap = picks.intersection(activityVerbs(a).toSet()).length;
    if (overlap >= 1) out.add(ActivityMatch(activity: a, overlap: overlap));
  }
  out.sort((x, y) {
    final byOverlap = y.overlap.compareTo(x.overlap);
    return byOverlap != 0
        ? byOverlap
        : x.activity.name.toLowerCase().compareTo(
            y.activity.name.toLowerCase(),
          );
  });
  return out;
}
