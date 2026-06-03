import 'dart:convert';

import 'package:differentworld/features/poster/poster_models.dart';
// shared_preferences IS a direct dep in pubspec.yaml; the analyzer can warn
// spuriously across pub workspace boundaries.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the poster tool's durable options (size / fit-shape / fit /
/// paper / labels) so a teacher's last choices come back next time. The
/// per-image bits (the picked image, its rotation) are deliberately NOT
/// persisted — they're meaningless without the image.
class PosterPrefs {
  const PosterPrefs._();

  static const _key = 'poster.options.v1';

  /// Load the saved options, or the defaults if nothing's saved / the blob
  /// is corrupt. Never throws.
  static Future<PosterOptions> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return const PosterOptions();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return PosterOptions(
        size: (map['size'] as num?)?.toInt().clamp(2, 5) ?? 2,
        fitShape: map['fitShape'] as bool? ?? true,
        orientation: _enumByName(
          PosterOrientation.values,
          map['orientation'],
          PosterOrientation.auto,
        ),
        fit: _enumByName(PosterFit.values, map['fit'], PosterFit.fill),
        paper: _enumByName(PosterPaper.values, map['paper'], PosterPaper.letter),
        quality: _enumByName(
          PosterQuality.values,
          map['quality'],
          PosterQuality.standard,
        ),
        labels: map['labels'] as bool? ?? true,
        guides: map['guides'] as bool? ?? false,
      );
    } on Object {
      return const PosterOptions();
    }
  }

  /// Save the options. Never throws (best-effort persistence).
  static Future<void> save(PosterOptions o) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'size': o.size,
          'fitShape': o.fitShape,
          'orientation': o.orientation.name,
          'fit': o.fit.name,
          'paper': o.paper.name,
          'quality': o.quality.name,
          'labels': o.labels,
          'guides': o.guides,
        }),
      );
    } on Object {
      // Best-effort — a failed write just means defaults next launch.
    }
  }

  static T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return fallback;
  }
}
