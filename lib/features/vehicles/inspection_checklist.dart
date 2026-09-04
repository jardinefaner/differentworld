import 'dart:convert';

/// Status of a single inspection item. Mirrors the FACES form's three
/// escalation tiers:
///   ok            — driver checked it; safe to drive
///   needsRepair   — flag for next mechanic visit; vehicle still drives
///   unsafe        — DO NOT DRIVE; report immediately
enum InspectionStatus {
  ok,
  needsRepair,
  unsafe;

  String get wire => switch (this) {
    InspectionStatus.ok => 'ok',
    InspectionStatus.needsRepair => 'needs_repair',
    InspectionStatus.unsafe => 'unsafe',
  };

  static InspectionStatus? fromWire(String? raw) => switch (raw) {
    'ok' => InspectionStatus.ok,
    'needs_repair' => InspectionStatus.needsRepair,
    'unsafe' => InspectionStatus.unsafe,
    _ => null,
  };

  String get label => switch (this) {
    InspectionStatus.ok => 'OK',
    InspectionStatus.needsRepair => 'Needs repair',
    InspectionStatus.unsafe => 'Unsafe — do not drive',
  };
}

/// One row on the FACES checklist. Section + item key + display label.
class InspectionItem {
  const InspectionItem({
    required this.section,
    required this.key,
    required this.label,
    this.subtitle,
  });

  final String section;
  final String key;
  final String label;
  final String? subtitle;
}

/// The full FACES checklist, in the order they appear on the paper form.
/// Keep this list in sync with how items appear in `vehicle_logs.items`
/// JSONB blobs — JSON keys are `section.key`.
abstract final class InspectionChecklist {
  static const items = <InspectionItem>[
    // Lights
    InspectionItem(section: 'lights', key: 'headlights', label: 'Headlights'),
    InspectionItem(section: 'lights', key: 'brake', label: 'Brake lights'),
    InspectionItem(section: 'lights', key: 'turn', label: 'Turn signals'),
    InspectionItem(section: 'lights', key: 'hazard', label: 'Hazard lights'),

    // Tires
    InspectionItem(
      section: 'tires',
      key: 'inflated',
      label: 'Properly inflated',
    ),

    // Gauges
    InspectionItem(section: 'gauges', key: 'fuel', label: 'Fuel'),
    InspectionItem(section: 'gauges', key: 'temperature', label: 'Temperature'),
    InspectionItem(
      section: 'gauges',
      key: 'engine_service',
      label: 'Engine service lights',
    ),

    // Leaks
    InspectionItem(
      section: 'leaks',
      key: 'oil',
      label: 'Oil',
      subtitle: 'Look underneath',
    ),
    InspectionItem(section: 'leaks', key: 'other', label: 'Other leaks'),

    // Other
    InspectionItem(
      section: 'other',
      key: 'windows_mirrors',
      label: 'Windows & mirrors',
    ),
    InspectionItem(section: 'other', key: 'wipers', label: 'Windshield wipers'),
    InspectionItem(
      section: 'other',
      key: 'fans_defroster',
      label: 'Fans & defroster',
    ),
    InspectionItem(
      section: 'other',
      key: 'brakes',
      label: 'Brakes',
      subtitle: 'Including parking brake',
    ),
    InspectionItem(section: 'other', key: 'horn', label: 'Horn'),
    InspectionItem(
      section: 'other',
      key: 'emergency_kit',
      label: 'Vehicle emergency / safety kit',
    ),

    // Interior
    InspectionItem(
      section: 'interior',
      key: 'noises',
      label: 'Noises',
      subtitle: 'Listen for unusual ones',
    ),
    InspectionItem(
      section: 'interior',
      key: 'seat_belts',
      label: 'Seat belts',
      subtitle: 'One per passenger',
    ),
  ];

  static const sectionLabels = <String, String>{
    'lights': 'Lights',
    'tires': 'Tires',
    'gauges': 'Gauges',
    'leaks': 'Leaks',
    'other': 'Other',
    'interior': 'Interior',
  };

  /// All section keys in the order they should render.
  static const sections = <String>[
    'lights',
    'tires',
    'gauges',
    'leaks',
    'other',
    'interior',
  ];

  static List<InspectionItem> itemsForSection(String section) =>
      items.where((i) => i.section == section).toList(growable: false);
}

/// In-memory model the form binds to. Wire format:
/// {"lights": {"headlights": "ok", "brake": "ok", ...}, ...}
class InspectionResults {
  InspectionResults({Map<String, Map<String, String>>? raw})
    : _raw = raw == null ? {} : _deepCopy(raw);

  factory InspectionResults.fromJson(String? json) {
    if (json == null || json.isEmpty) return InspectionResults();
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return InspectionResults();
      final out = <String, Map<String, String>>{};
      for (final entry in decoded.entries) {
        final inner = entry.value;
        if (inner is! Map) continue;
        out[entry.key.toString()] = {
          for (final ie in inner.entries)
            ie.key.toString(): ie.value.toString(),
        };
      }
      return InspectionResults(raw: out);
    } on FormatException {
      return InspectionResults();
    }
  }

  final Map<String, Map<String, String>> _raw;

  InspectionStatus? statusFor(InspectionItem item) {
    final inner = _raw[item.section];
    if (inner == null) return null;
    return InspectionStatus.fromWire(inner[item.key]);
  }

  void setStatus(InspectionItem item, InspectionStatus? status) {
    final inner = _raw.putIfAbsent(item.section, () => {});
    if (status == null) {
      inner.remove(item.key);
    } else {
      inner[item.key] = status.wire;
    }
  }

  /// True if every item on the checklist has been assigned a status.
  bool get isComplete {
    for (final item in InspectionChecklist.items) {
      if (statusFor(item) == null) return false;
    }
    return true;
  }

  /// Worst level recorded across all items. ok < needsRepair < unsafe.
  /// Null when nothing's been filled out yet.
  InspectionStatus? get worst {
    InspectionStatus? worst;
    for (final item in InspectionChecklist.items) {
      final s = statusFor(item);
      if (s == null) continue;
      if (worst == null || s.index > worst.index) worst = s;
    }
    return worst;
  }

  String toJson() => jsonEncode(_raw);

  static Map<String, Map<String, String>> _deepCopy(
    Map<String, Map<String, String>> src,
  ) => {for (final e in src.entries) e.key: Map<String, String>.from(e.value)};
}
