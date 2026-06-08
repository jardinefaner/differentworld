import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A rung on the **staff growth ladder** (docs/VISION.md "a staff growth
/// ladder… earned by practice, not tenure"). Shadow → Extra Hands → Co-Pilot
/// → Conductor. This is a GROWTH reflection, not a permission gate — the real
/// authority gate stays the member role (director / lead / teacher). It
/// mirrors the kid's own arc: the kid becomes a character, the helper becomes
/// a Conductor.
@immutable
class StaffRole {
  const StaffRole({
    required this.id,
    required this.name,
    required this.emoji,
    required this.duration,
    required this.desc,
    required this.canDo,
    required this.cantDo,
  });

  factory StaffRole.fromJson(Map<String, dynamic> j) => StaffRole(
    id: (j['id'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    emoji: (j['emoji'] as String?) ?? '•',
    duration: (j['duration'] as String?) ?? '',
    desc: (j['desc'] as String?) ?? '',
    canDo: [for (final c in (j['canDo'] as List? ?? const [])) c.toString()],
    cantDo: [
      for (final c in (j['cantDo'] as List? ?? const [])) c.toString(),
    ],
  );

  final String id;
  final String name;
  final String emoji;
  final String duration;
  final String desc;

  /// What this rung is cleared to do.
  final List<String> canDo;

  /// What this rung is NOT YET cleared to do — the next thing to grow into.
  final List<String> cantDo;
}

/// The ladder, in order (least → most responsibility), bundled offline.
final staffRolesProvider = FutureProvider<List<StaffRole>>((ref) async {
  final raw = await rootBundle.loadString(
    'assets/curriculum/staff_roles.json',
  );
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) return const [];
  final roles = decoded['roles'];
  if (roles is! List) return const [];
  return [
    for (final r in roles)
      if (r is Map<String, dynamic>) StaffRole.fromJson(r),
  ];
});

/// Where the current user marks themselves on the ladder. Stored LOCALLY per
/// device (SharedPreferences) — a personal growth marker, not synced authority
/// (mirrors the text-scale / outdoor-mode settings). Default: the first rung.
final staffLevelProvider = AsyncNotifierProvider<StaffLevelNotifier, String>(
  StaffLevelNotifier.new,
);

class StaffLevelNotifier extends AsyncNotifier<String> {
  static const _kKey = 'staff.ladder_level';
  static const _default = 'shadow';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kKey) ?? _default;
  }

  Future<void> set(String roleId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, roleId);
    state = AsyncData(roleId);
  }
}
