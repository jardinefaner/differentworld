import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';

/// Typed accessor over a JSONB `capabilities` blob stored on Space /
/// Member / Group / Subject. Read like a Map, mutate by returning a
/// new instance, serialize back to JSON for persistence.
class Capabilities {
  Capabilities(this._raw);

  factory Capabilities.fromJson(String? json) {
    if (json == null || json.isEmpty) return const Capabilities.empty();
    try {
      var decoded = jsonDecode(json);
      // Tolerate double-encoded values. Old rows in the DB were uploaded
      // as JSON-encoded strings instead of jsonb objects (fixed in the
      // supabase_connector), so PowerSync brought them back as a string
      // that wraps another JSON string. Decode again when we see one.
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      if (decoded is Map<String, dynamic>) return Capabilities(decoded);
      // jsonDecode of a JSON object returns Map<String, dynamic>, but a
      // generic Map (e.g. from deeply-nested re-encoding) may not exactly
      // match the generic. Coerce keys to String defensively.
      if (decoded is Map) {
        return Capabilities(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
      return const Capabilities.empty();
    } on FormatException {
      return const Capabilities.empty();
    }
  }

  const Capabilities.empty() : _raw = const <String, dynamic>{};

  final Map<String, dynamic> _raw;

  bool has(String key) => _raw.containsKey(key);

  T? get<T>(String key) {
    final v = _raw[key];
    if (v == null) return null;
    if (v is T) return v;
    return null;
  }

  bool getBool(String key, {bool fallback = false}) {
    final v = _raw[key];
    if (v is bool) return v;
    return fallback;
  }

  String? getString(String key) => get<String>(key);

  int? getInt(String key) {
    final v = _raw[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return null;
  }

  List<String> getStringList(String key) {
    final v = _raw[key];
    if (v is List) return v.whereType<String>().toList(growable: false);
    return const [];
  }

  Map<String, String> getStringMap(String key) {
    final v = _raw[key];
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), val.toString()));
    }
    return const {};
  }

  /// Returns a new Capabilities with `key` set to `value`.
  Capabilities setting(String key, Object? value) {
    final next = Map<String, dynamic>.from(_raw);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return Capabilities(next);
  }

  /// Returns a new Capabilities with the entries of `other` merged on
  /// top of this one (existing keys are overwritten).
  Capabilities mergedWith(Map<String, dynamic> other) {
    final next = Map<String, dynamic>.from(_raw)..addAll(other);
    return Capabilities(next);
  }

  Map<String, dynamic> toMap() => Map<String, dynamic>.unmodifiable(_raw);

  String toJson() => jsonEncode(_raw);
}

// ---------------------------------------------------------------------------
// Extensions on each entity to read its capabilities ergonomically.
// ---------------------------------------------------------------------------

extension SpaceCapsX on Space {
  Capabilities get caps => Capabilities.fromJson(capabilities);
}

extension MemberCapsX on Member {
  Capabilities get caps => Capabilities.fromJson(capabilities);
}

extension GroupCapsX on Group {
  Capabilities get caps => Capabilities.fromJson(capabilities);
}

extension SubjectCapsX on Subject {
  Capabilities get caps => Capabilities.fromJson(capabilities);
}
