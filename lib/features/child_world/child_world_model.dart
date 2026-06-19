// The per-child world (docs/VISION.md 2026-06-19 — the dailies / weeklies /
// projects arc, made personal): each child owns their weekly intention, their
// own project, today's answer, and their growth. The render models for the
// structured pieces live here; the hub assembles them (child_world_providers).

/// A child's project for the week — title + ordered steps + how many are done.
/// Parsed from a `project` entry's details ({week, title, steps[], done}).
class ProjectView {
  const ProjectView({
    required this.week,
    required this.title,
    required this.steps,
    required this.done,
  });

  factory ProjectView.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    return ProjectView(
      week: (json['week'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?) ?? '',
      steps: rawSteps is List ? [for (final s in rawSteps) '$s'] : const [],
      done: (json['done'] as num?)?.toInt() ?? 0,
    );
  }

  final int week;
  final String title;
  final List<String> steps;
  final int done;

  /// True once there's a real project (a title) to show.
  bool get hasProject => title.trim().isNotEmpty;

  int get total => steps.length;

  /// Steps done, clamped — tolerant of a stale `done` past the step count.
  int get doneClamped => done.clamp(0, total);

  bool get isComplete => total > 0 && doneClamped >= total;

  /// 0.0–1.0 for the progress bar (0 when there are no steps yet).
  double get progress => total == 0 ? 0 : doneClamped / total;

  /// The next step to do, or null when complete / stepless.
  String? get nextStep =>
      (total > 0 && doneClamped < total) ? steps[doneClamped] : null;
}
