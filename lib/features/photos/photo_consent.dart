/// Photo consent, enforced (docs/CONSENT.md).
///
/// `SubjectCaps.photoConsent` existed in the capability catalogue with ZERO
/// call sites: nothing read it, nothing wrote it, and only a program-wide
/// default toggle was wired. So a child whose family had declined could be
/// photographed, land on the program photo wall, ride into the family lens
/// and appear in an exported PDF — with a key in the codebase that read as
/// though it were handled. This module is that key becoming real.
///
/// **Blank is not the same as "no".** Three states, because on the first day
/// most children genuinely have no answer recorded yet, and treating that
/// silence as a refusal would make the app unusable while treating it as
/// permission is what the regulator objects to. Unknown falls back to the
/// program's declared default posture, and is surfaced as a gap to close
/// while the family is still standing in the room.
library;

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';

enum PhotoConsent {
  /// Nobody has answered yet. Real, common, and not a decision.
  unknown,

  /// The family said yes.
  allowed,

  /// The family said no. Never overridden by a program default.
  declined;

  bool get isDeclined => this == PhotoConsent.declined;
}

/// What has been recorded for [subject], ignoring any program default.
PhotoConsent recordedConsent(Subject subject) {
  // get<bool> (nullable), NOT getBool (which folds a missing key into
  // `false`) — the whole point is telling "no answer" from "no".
  final v = subject.caps.get<bool>(SubjectCaps.photoConsent);
  if (v == null) return PhotoConsent.unknown;
  return v ? PhotoConsent.allowed : PhotoConsent.declined;
}

/// Whether a photo of [subject] may be taken, shown or exported.
///
/// A recorded "no" always wins — [spaceDefaultAllows] can only decide the
/// unknown case, never overturn a family's answer.
bool photosAllowedFor(Subject subject, {required bool spaceDefaultAllows}) {
  return switch (recordedConsent(subject)) {
    PhotoConsent.declined => false,
    PhotoConsent.allowed => true,
    PhotoConsent.unknown => spaceDefaultAllows,
  };
}

/// The children on this roster with no answer recorded — the day-one gap
/// worth closing while every family is physically present.
List<Subject> awaitingConsent(Iterable<Subject> roster) => [
  for (final s in roster)
    if (recordedConsent(s) == PhotoConsent.unknown) s,
];

/// Drop attachments belonging to a child who may not be photographed.
///
/// Applied at RENDER, not only at capture, because consent can be withdrawn
/// after a photo was taken — and the honest response to "please stop using
/// our child's picture" is that it disappears from the wall, the family lens
/// and every future export, not that it stays because it predates the ask.
List<Attachment> withoutDeclinedSubjects(
  List<Attachment> photos, {
  required Map<String, Subject> subjectsById,
  required bool spaceDefaultAllows,
}) {
  bool permitted(String? id) {
    if (id == null) return true; // not about a child
    final s = subjectsById[id];
    if (s == null) return true; // unknown row — not ours to censor
    return photosAllowedFor(s, spaceDefaultAllows: spaceDefaultAllows);
  }

  return [
    for (final a in photos)
      // Both the child the photo is OF and the child who TOOK it (photo
      // turns) have to permit it — a declining family's child appearing as
      // the photographer is still their child on the wall.
      if (permitted(a.subjectId) && permitted(a.capturedBySubjectId)) a,
  ];
}
