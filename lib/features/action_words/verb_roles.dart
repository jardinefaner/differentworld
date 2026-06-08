import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The **verb spine** (docs/VISION.md "the 12 verbs as one vocabulary, three
/// lives"): each verb is a kid's identity (the pick), a kid's JOB for the day
/// (with a helper script of exact words), and a staff SKILL that deepens over
/// three levels. This carries the job + mission + staff-skill side; the pick
/// itself lives in `verbs.dart`.
@immutable
class VerbJob {
  const VerbJob({
    required this.job,
    required this.what,
    required this.helperSays,
  });

  factory VerbJob.fromJson(Map<String, dynamic> j) => VerbJob(
    job: (j['job'] as String?) ?? '',
    what: (j['what'] as String?) ?? '',
    helperSays: (j['helperSays'] as String?) ?? '',
  );

  final String job;
  final String what;

  /// The exact words a helper says to hand a kid this job — the scripted
  /// micro-language that lets a nervous new helper just read it aloud.
  final String helperSays;
}

/// A staff skill at one of three depths for a verb (CARRY L1 = carry
/// materials; L3 = carry the room's energy).
@immutable
class StaffSkill {
  const StaffSkill({
    required this.level,
    required this.skill,
    required this.desc,
  });

  factory StaffSkill.fromJson(Map<String, dynamic> j) => StaffSkill(
    level: (j['level'] as num?)?.toInt() ?? 1,
    skill: (j['skill'] as String?) ?? '',
    desc: (j['desc'] as String?) ?? '',
  );

  final int level;
  final String skill;
  final String desc;
}

/// A 3-level kid mission for a verb + the helper's coaching note.
@immutable
class VerbMission {
  const VerbMission({
    required this.level1,
    required this.level2,
    required this.level3,
    required this.helperGuide,
  });

  factory VerbMission.fromJson(Map<String, dynamic> j) => VerbMission(
    level1: (j['level1'] as String?) ?? '',
    level2: (j['level2'] as String?) ?? '',
    level3: (j['level3'] as String?) ?? '',
    helperGuide: (j['helperGuide'] as String?) ?? '',
  );

  final String level1;
  final String level2;
  final String level3;

  /// Coaching for the adult running this mission — the "how", not the "what".
  final String helperGuide;

  List<String> get levels => [level1, level2, level3];
}

/// Everything a verb means beyond the pick — the day's job, the mission, the
/// staff-growth ladder. Keyed by the same verb id as `kVerbs`.
@immutable
class VerbRole {
  const VerbRole({
    required this.verbId,
    required this.jobTitle,
    required this.jobs,
    required this.mission,
    required this.staffSkills,
  });

  factory VerbRole.fromJson(String verbId, Map<String, dynamic> j) => VerbRole(
    verbId: verbId,
    jobTitle: (j['jobTitle'] as String?) ?? '',
    jobs: [
      for (final job in (j['jobs'] as List? ?? const []))
        if (job is Map<String, dynamic>) VerbJob.fromJson(job),
    ],
    mission: VerbMission.fromJson(
      (j['mission'] as Map<String, dynamic>?) ?? const {},
    ),
    staffSkills: [
      for (final s in (j['staffSkills'] as List? ?? const []))
        if (s is Map<String, dynamic>) StaffSkill.fromJson(s),
    ],
  );

  final String verbId;

  /// The kid-facing title of today's job ("The Mover", "The Ear").
  final String jobTitle;
  final List<VerbJob> jobs;
  final VerbMission mission;
  final List<StaffSkill> staffSkills;
}

/// The verb-roles map, loaded once from the bundled JSON (offline-first),
/// keyed by verb id.
final verbRolesProvider = FutureProvider<Map<String, VerbRole>>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/curriculum/verb_roles.json',
  );
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const {};
  final roles = decoded['roles'];
  if (roles is! Map<String, dynamic>) return const {};
  return {
    for (final entry in roles.entries)
      if (entry.value is Map<String, dynamic>)
        entry.key: VerbRole.fromJson(
          entry.key,
          entry.value as Map<String, dynamic>,
        ),
  };
});

/// The role for a single verb id (null if the journey JSON lacks it).
// ignore: specify_nonobvious_property_types — family provider, no stable name
final verbRoleProvider = Provider.family<VerbRole?, String>((ref, verbId) {
  return ref.watch(verbRolesProvider).value?[verbId];
});
