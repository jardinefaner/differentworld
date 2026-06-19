import 'package:differentworld/features/action_words/summer_book.dart'
    show scrubOtherNames;

/// The **daily parent recap** (docs/VISION.md 2026-06-19: "every day, what we
/// learn from today is shared with parents… community"). Each child's family
/// receives the room's shared day PLUS that child's own moments.
///
/// Storage: one `entries` row per child (kind `recap`, `subject_id` set), so it
/// rides the EXISTING per-subject family path (`familyEntriesForSubjectProvider`)
/// with no new family-lens plumbing. The per-child row is also where privacy
/// lives — each child's copy is scrubbed of every OTHER child's name BEFORE it's
/// stored, so a family-facing artifact can never name another child (the
/// recurring scrub rule; acceptance test in recap_model_test.dart).

/// What the composer hands `recordRecap` for one child.
class RecapChildInput {
  const RecapChildInput({
    required this.subjectId,
    required this.firstName,
    required this.ownNames,
    this.heroName,
    this.answer,
  });

  final String subjectId;
  final String firstName;

  /// This child's own name tokens (first + last) — the names NOT scrubbed from
  /// their copy. The scrub pool for a child is `everyone's names − ownNames`.
  final Set<String> ownNames;

  /// This child's hero name today, if they have one.
  final String? heroName;

  /// This child's own answer to the day's question, if they gave one.
  final String? answer;
}

/// Build the stored `details` map for ONE child's recap entry — the room's
/// shared day + this child's moments, with every free-text field scrubbed of
/// [otherNames] (the roster minus this child). Pure + total so the scrub is
/// unit-testable in isolation.
Map<String, dynamic> recapDetailsForChild({
  required String date,
  required List<String> activities,
  required RecapChildInput child,
  required Set<String> otherNames,
  String? question,
  String? momentNote,
}) {
  String? clean(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s.trim();
  final moment = clean(momentNote) == null
      ? null
      : scrubOtherNames(clean(momentNote)!, otherNames);
  final answer = clean(child.answer) == null
      ? null
      : scrubOtherNames(clean(child.answer)!, otherNames);
  final q = clean(question);
  final hero = clean(child.heroName);
  return <String, dynamic>{
    'date': date,
    'activities': activities,
    'question': ?q,
    'moment': ?moment,
    'child': <String, dynamic>{
      'name': child.firstName,
      'hero': ?hero,
      'answer': ?answer,
    },
  };
}

/// The render model — parses a recap entry's `details` for the family card.
class RecapView {
  const RecapView({
    required this.date,
    required this.activities,
    required this.childName,
    this.question,
    this.moment,
    this.heroName,
    this.answer,
  });

  /// Parse the stored details map. Tolerant of missing keys (an older or
  /// partial recap still renders what it has).
  factory RecapView.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'];
    final child = json['child'];
    final childMap = child is Map ? child : const <dynamic, dynamic>{};
    return RecapView(
      date: (json['date'] as String?) ?? '',
      activities: rawActivities is List
          ? rawActivities.map((e) => '$e').toList()
          : const <String>[],
      question: json['question'] as String?,
      moment: json['moment'] as String?,
      childName: (childMap['name'] as String?) ?? '',
      heroName: childMap['hero'] as String?,
      answer: childMap['answer'] as String?,
    );
  }

  final String date;
  final List<String> activities;
  final String? question;
  final String? moment;
  final String childName;
  final String? heroName;
  final String? answer;

  /// True when there's at least one personal touch for this child (beyond the
  /// shared room day) — drives whether the "their moments" section renders.
  bool get hasChildMoments =>
      (heroName != null && heroName!.isNotEmpty) ||
      (answer != null && answer!.isNotEmpty);
}
