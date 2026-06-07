import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:flutter/foundation.dart';

/// A parsed time capsule (docs/WORLD.md — Week 8 "seal in a box, open Week
/// 10"). Sealed (the contents hidden) until [sealedUntil] passes.
@immutable
class TimeCapsule {
  const TimeCapsule({
    required this.id,
    required this.text,
    required this.sealedUntil,
    required this.buriedAt,
  });

  factory TimeCapsule.fromEntry(Entry e) {
    Map<String, dynamic> details;
    try {
      final d = jsonDecode(e.details);
      details = d is Map<String, dynamic> ? d : const {};
    } on FormatException {
      details = const {};
    }
    return TimeCapsule(
      id: e.id,
      text: e.body ?? '',
      sealedUntil: DateTime.tryParse((details['sealed_until'] as String?) ?? ''),
      buriedAt: e.recordedAt,
    );
  }

  final String id;
  final String text;
  final DateTime? sealedUntil;
  final String buriedAt;

  bool sealedAt(DateTime now) => capsuleIsSealed(sealedUntil, now);
}

/// A capsule is sealed until its date passes (date-only comparison).
bool capsuleIsSealed(DateTime? sealedUntil, DateTime now) {
  if (sealedUntil == null) return false;
  final until = DateTime(sealedUntil.year, sealedUntil.month, sealedUntil.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.isBefore(until);
}

/// Capsules sorted: sealed first (soonest to open), then opened (newest).
List<TimeCapsule> sortCapsules(List<Entry> entries, DateTime now) {
  final capsules = [for (final e in entries) TimeCapsule.fromEntry(e)]
    ..sort((a, b) {
    final aSealed = a.sealedAt(now);
    final bSealed = b.sealedAt(now);
    if (aSealed != bSealed) return aSealed ? -1 : 1;
    if (aSealed) {
      // Sealed: soonest to open first.
      final au = a.sealedUntil ?? DateTime(9999);
      final bu = b.sealedUntil ?? DateTime(9999);
      return au.compareTo(bu);
    }
    // Opened: newest buried first.
    return b.buriedAt.compareTo(a.buriedAt);
  });
  return capsules;
}
