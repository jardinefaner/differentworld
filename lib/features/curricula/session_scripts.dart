// Registry of every runnable SESSION SCRIPT — the join point between a
// session slug and its full beat sequence. Each script lives in its own
// data file (photo_s1_script.dart, photo_s2_script.dart, …); this file is
// the single list + the slug lookup so callers depend on the registry, not
// on any one session's data file.
//
// Plain Dart const data: no codegen. Add a new session by importing its
// data file and adding its const to [allSessionScripts].

import 'package:differentworld/features/curricula/photo_s1_script.dart';
import 'package:differentworld/features/curricula/photo_s2_script.dart';
import 'package:differentworld/features/curricula/photo_s3_script.dart';
import 'package:differentworld/features/curricula/photo_s4_script.dart';
import 'package:differentworld/features/curricula/photo_s5_script.dart';
import 'package:differentworld/features/curricula/photo_s6_script.dart';
import 'package:differentworld/features/curricula/session_script.dart';

/// Every encoded session script, in session order.
const List<SessionScript> allSessionScripts = [
  photoSession1Script,
  photoSession2Script,
  photoSession3Script,
  photoSession4Script,
  photoSession5Script,
  photoSession6Script,
];

/// Resolve the full script for a session slug. Returns null when no script
/// has been encoded for that slug yet.
SessionScript? scriptForSession(String slug) {
  for (final s in allSessionScripts) {
    if (s.slug == slug) return s;
  }
  return null;
}
