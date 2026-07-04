import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:flutter/material.dart';

/// The Mood Weather scale — "fingers up, 1 is a black hole, 5 is a
/// supernova" (docs/WORLD.md). A weather metaphor a 4–12-year-old reads at a
/// glance; never judged, just noticed.
enum MoodLevel {
  stormy(1, '⛈️', 'Stormy', Color(0xFF5C6BC0)),
  rainy(2, '🌧️', 'Rainy', Color(0xFF4FC3F7)),
  cloudy(3, '⛅', 'Cloudy', Color(0xFF90A4AE)),
  sunny(4, '🌤️', 'Sunny', Color(0xFFFFB74D)),
  bright(5, '☀️', 'Bright', Color(0xFFFFD54F))
  ;

  const MoodLevel(this.value, this.emoji, this.label, this.color);
  final int value;
  final String emoji;
  final String label;
  final Color color;

  static MoodLevel fromValue(int v) {
    for (final m in values) {
      if (m.value == v) return m;
    }
    return cloudy;
  }
}

/// A parsed mood check.
@immutable
class MoodReading {
  const MoodReading({required this.level, required this.recordedAt});

  factory MoodReading.fromEntry(Entry e) {
    var value = 3;
    try {
      final d = jsonDecode(e.details);
      if (d is Map && d['value'] is num) value = (d['value'] as num).toInt();
    } on FormatException {
      // keep default
    }
    return MoodReading(
      level: MoodLevel.fromValue(value),
      recordedAt: e.recordedAt,
    );
  }

  final MoodLevel level;
  final String recordedAt;
}

/// Parse mood entries (newest-first as stored) into readings.
List<MoodReading> moodReadings(List<Entry> entries) => [
  for (final e in entries) MoodReading.fromEntry(e),
];
