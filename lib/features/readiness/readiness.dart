/// What today needs — computed, not remembered (docs/READINESS.md).
///
/// The app already knows what a complete child record looks like and what a
/// running day needs. So instead of twenty drawer destinations and a
/// director who has to remember which ones to check, it can show the
/// DIFFERENCE — and show nothing at all once there isn't one.
///
/// Two rules keep this from becoming a nag:
///
/// 1. **Every item is fixable now.** Nothing appears here that you can't
///    act on in the next minute. "6 children have no photo" earns its place
///    on the first morning precisely because every family is standing in the
///    room; the same line in November is noise.
/// 2. **It disappears when satisfied.** An item that lingers after you have
///    done the thing is worse than no item, and a card that is always on
///    screen is a sign on a wall (CLAUDE.md, the half-second rule).
library;

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/photos/photo_consent.dart';

enum ReadinessKind {
  /// No photo on file — and the family is here today.
  missingPhoto,

  /// Nobody has answered the photo question. Blocks nothing, but it is the
  /// answer that is impossible to collect once everyone has gone home.
  missingConsent,

  /// No guardian at all: nobody to call.
  missingGuardian,

  /// The allergy field has never been filled in. Blank is not "none" —
  /// "none" is something a person typed after asking.
  missingAllergyAnswer,

  /// A cohort that has never been arranged. On the first day children clump
  /// with whoever they arrived with; this is the one round that decides
  /// whether they meet anybody else.
  neverArranged,
}

class ReadinessItem {
  const ReadinessItem({
    required this.kind,
    required this.count,
    this.names = const [],
    this.groupId,
    this.groupName,
  });

  final ReadinessKind kind;
  final int count;

  /// Up to three names, for a line that names people rather than counting
  /// them — "Owen, Ava, Liam and 3 more" is actionable; "6 children" is a
  /// statistic.
  final List<String> names;

  final String? groupId;
  final String? groupName;
}

/// Everything today needs, most urgent first, omitting anything already done.
///
/// [subjectIdsWithGuardian] is passed in rather than looked up so this stays
/// pure and testable — the caller owns the query.
List<ReadinessItem> computeReadiness({
  required List<Subject> roster,
  required Set<String> subjectIdsWithGuardian,
  required bool spaceDefaultAllowsPhotos,
  List<Group> groups = const [],
  Set<String> arrangedGroupIds = const {},
}) {
  // Alumni are not today's problem. They keep every record they ever had,
  // and none of it needs completing.
  final active = [
    for (final s in roster)
      if (s.status != 'alumni') s,
  ];

  String nameOf(Subject s) =>
      s.firstName.trim().isEmpty ? s.lastName.trim() : s.firstName.trim();

  ReadinessItem? item(ReadinessKind kind, List<Subject> matches) {
    if (matches.isEmpty) return null;
    return ReadinessItem(
      kind: kind,
      count: matches.length,
      names: [for (final s in matches.take(3)) nameOf(s)],
    );
  }

  final noPhoto = [
    for (final s in active)
      // A child nobody may photograph is not missing a photo — asking for
      // one would be asking you to break the rule two lines above.
      if ((s.photoUrl == null || s.photoUrl!.trim().isEmpty) &&
          photosAllowedFor(s, spaceDefaultAllows: spaceDefaultAllowsPhotos))
        s,
  ];
  final noConsent = awaitingConsent(active);
  final noGuardian = [
    for (final s in active)
      if (!subjectIdsWithGuardian.contains(s.id)) s,
  ];
  final noAllergyAnswer = [
    for (final s in active)
      if (s.allergies == null || s.allergies!.trim().isEmpty) s,
  ];

  final unarranged = [
    for (final g in groups)
      if (!arrangedGroupIds.contains(g.id) &&
          active.any((s) => s.groupId == g.id))
        ReadinessItem(
          kind: ReadinessKind.neverArranged,
          count: active.where((s) => s.groupId == g.id).length,
          groupId: g.id,
          groupName: g.name,
        ),
  ];

  return [
    // Ordered by what it costs to miss: somebody unreachable in an
    // emergency, then a medical unknown, then the two things only
    // collectable while the family is physically present.
    ?item(ReadinessKind.missingGuardian, noGuardian),
    ?item(ReadinessKind.missingAllergyAnswer, noAllergyAnswer),
    ?item(ReadinessKind.missingConsent, noConsent),
    ?item(ReadinessKind.missingPhoto, noPhoto),
    ...unarranged,
  ];
}
