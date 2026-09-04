import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// A kind of block in the day's rhythm. Carries an emoji + label for the
/// palette and maps to the `schedule_blocks.kind` the runtime understands
/// (on_site / break / field_trip) when a template is applied to a date.
enum DayBlockKind {
  arrival('🛬', 'Arrival', 'on_site', 0.25),
  circle('⭕', 'Circle', 'on_site', 0.35),
  activity('🎯', 'Activity', 'on_site', 0.65),
  outdoor('🌳', 'Outdoor', 'on_site', 0.85),
  meal('🍎', 'Snack / Meal', 'break', 0.3),
  rest('😴', 'Rest', 'break', 0.2),
  story('📖', 'Story', 'on_site', 0.3),
  free('🧸', 'Free play', 'on_site', 0.9),
  transition('🔁', 'Transition', 'on_site', 0.4),
  pickup('👋', 'Pickup', 'on_site', 0.18),
  fieldTrip('🚌', 'Field trip', 'field_trip', 0.9);

  const DayBlockKind(this.emoji, this.label, this.scheduleKind, this.energy);
  final String emoji;
  final String label;
  final String scheduleKind;

  /// Where this kind sits in the day's energy arc, 0..1 (calm → peak) — drives
  /// the arc preview in the template editor (docs/VISION.md "the order is an
  /// arc").
  final double energy;

  static DayBlockKind fromName(String? name) {
    for (final k in DayBlockKind.values) {
      if (k.name == name) return k;
    }
    return DayBlockKind.activity;
  }
}

/// The duration presets a director picks from (minutes). Custom durations
/// are allowed too, but these cover the common cases.
const List<int> kBlockDurations = [5, 10, 15, 20, 30, 45, 60, 90];

/// One block in a day template — a DURATION, not a fixed clock time. The
/// clock times are DERIVED by packing blocks from the day's start, so
/// reordering just re-packs (the whole point: move blocks freely without
/// re-entering times).
@immutable
class DayBlock {
  const DayBlock({
    required this.id,
    required this.label,
    required this.minutes,
    required this.kind,
    this.energy,
  });

  factory DayBlock.fromJson(Map<String, dynamic> j) => DayBlock(
    id: (j['id'] as String?) ?? const Uuid().v4(),
    label: (j['label'] as String?) ?? '',
    minutes: (j['minutes'] as num?)?.toInt() ?? 15,
    kind: DayBlockKind.fromName(j['kind'] as String?),
    energy: (j['energy'] as num?)?.toDouble(),
  );

  final String id;
  final String label;
  final int minutes;
  final DayBlockKind kind;

  /// Hand-tuned energy 0..1 for the arc; null = derive from [kind].
  final double? energy;

  DayBlock copyWith({
    String? label,
    int? minutes,
    DayBlockKind? kind,
    double? energy,
  }) => DayBlock(
    id: id,
    label: label ?? this.label,
    minutes: minutes ?? this.minutes,
    kind: kind ?? this.kind,
    energy: energy ?? this.energy,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'minutes': minutes,
    'kind': kind.name,
    if (energy != null) 'energy': energy,
  };
}

/// A packed block: a [DayBlock] with its DERIVED clock window, in minutes
/// from midnight.
@immutable
class DaySlot {
  const DaySlot({
    required this.block,
    required this.startMinute,
    required this.endMinute,
  });
  final DayBlock block;
  final int startMinute;
  final int endMinute;
}

/// A reusable shape of the day — a named, ordered list of duration-blocks
/// between a start and end time. The director authors these (a small
/// library: "Regular day", "Field-trip day", "Early release"); applying one
/// to a date generates real `schedule_blocks`. Stored as JSON on the
/// Space's capabilities (no table) — director-authored, read-mostly.
@immutable
class DayTemplate {
  const DayTemplate({
    required this.id,
    required this.name,
    required this.startMinute,
    required this.endMinute,
    required this.blocks,
  });

  factory DayTemplate.fromJson(Map<String, dynamic> j) => DayTemplate(
    id: (j['id'] as String?) ?? const Uuid().v4(),
    name: (j['name'] as String?) ?? 'Day',
    startMinute: (j['start'] as num?)?.toInt() ?? 9 * 60,
    endMinute: (j['end'] as num?)?.toInt() ?? 15 * 60,
    blocks: [
      for (final b in (j['blocks'] as List? ?? const []))
        if (b is Map<String, dynamic>) DayBlock.fromJson(b),
    ],
  );

  /// A sensible starter so "New template" isn't a blank canvas — an
  /// afterschool-shaped afternoon the director can reshape.
  factory DayTemplate.starter({required String name}) {
    const uuid = Uuid();
    DayBlock b(String label, int minutes, DayBlockKind kind) =>
        DayBlock(id: uuid.v4(), label: label, minutes: minutes, kind: kind);
    return DayTemplate(
      id: uuid.v4(),
      name: name,
      startMinute: 15 * 60, // 3:00 PM
      endMinute: 18 * 60, // 6:00 PM
      blocks: [
        b('Arrival & check-in', 15, DayBlockKind.arrival),
        b('Snack', 15, DayBlockKind.meal),
        b('Circle / words', 15, DayBlockKind.circle),
        b('Activity', 45, DayBlockKind.activity),
        b('Outdoor', 45, DayBlockKind.outdoor),
        b('Free play', 30, DayBlockKind.free),
        b('Pickup', 15, DayBlockKind.pickup),
      ],
    );
  }

  /// A CONTEXT-AWARE draft of a day — the "propose the day" move (docs/VISION.md
  /// "the app walks in already holding a draft of your day"). Shaped from the
  /// program's hours ([startMinute]..[endMinute] — usually the phase windows'
  /// arrival→closed) + this week's [worldName]. The four bookends/transitions
  /// are fixed; the three program blocks (photo rotation / make / outdoor)
  /// absorb the rest of the window, so the draft fills ANY hours. The photo
  /// block is named "Photo rotation" so the day-run auto-fills it with today's
  /// photo class. Pure — the provider supplies the live context.
  factory DayTemplate.proposed({
    required int startMinute,
    required int endMinute,
    String? worldName,
  }) {
    const uuid = Uuid();
    final span = (endMinute - startMinute).clamp(60, 12 * 60);
    const fixed = 15 * 4; // arrival + welcome + snack + pickup
    // Whatever's left after the bookends — never force a floor that would push
    // the draft past the program's end (overfill) on a short day.
    final flex = (span - fixed).clamp(0, 11 * 60);
    final photo = (flex * 0.38).round();
    final make = (flex * 0.34).round();
    final outdoor = (flex - photo - make).clamp(0, 11 * 60);
    final world = (worldName ?? '').trim();
    DayBlock b(String label, int minutes, DayBlockKind kind) =>
        DayBlock(id: uuid.v4(), label: label, minutes: minutes, kind: kind);
    // DETERMINISTIC id (per hours + world) — so re-drafting the same day
    // REPLACES its saved copy instead of piling up "Ocean day" duplicates when
    // the host taps "Tweak first" across sessions (restoreTemplate is
    // idempotent by id). Block ids stay random (they're regenerated each draft).
    final slug = world.isEmpty
        ? 'day'
        : world.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
    return DayTemplate(
      id: 'proposed-$startMinute-$endMinute-$slug',
      name: world.isEmpty ? 'Proposed day' : '$world day',
      startMinute: startMinute,
      endMinute: endMinute,
      blocks: [
        b('Arrival & check-in', 15, DayBlockKind.arrival),
        b(
          world.isEmpty ? 'Welcome / circle' : 'Welcome · $world',
          15,
          DayBlockKind.circle,
        ),
        b('Snack', 15, DayBlockKind.meal),
        b('Photo rotation', photo, DayBlockKind.activity),
        b(
          world.isEmpty ? 'Make' : 'Make · $world',
          make,
          DayBlockKind.activity,
        ),
        b('Outdoor play', outdoor, DayBlockKind.outdoor),
        b('Pack up & pickup', 15, DayBlockKind.pickup),
      ],
    );
  }

  final String id;
  final String name;

  /// Minutes from midnight (9:00 AM = 540).
  final int startMinute;
  final int endMinute;
  final List<DayBlock> blocks;

  /// Total minutes between the day's start and end.
  int get spanMinutes => (endMinute - startMinute).clamp(0, 24 * 60);

  /// Sum of the block durations.
  int get plannedMinutes => blocks.fold(0, (sum, b) => sum + b.minutes);

  /// Span minus planned. Negative = the blocks overflow the day's end.
  int get freeMinutes => spanMinutes - plannedMinutes;

  bool get isOverfilled => freeMinutes < 0;

  /// The packed schedule — each block's derived clock window, laid end to
  /// end from [startMinute]. The last block can run past [endMinute] (that
  /// surfaces as [isOverfilled]); we don't clip it.
  List<DaySlot> get schedule {
    final slots = <DaySlot>[];
    var cursor = startMinute;
    for (final b in blocks) {
      slots.add(
        DaySlot(block: b, startMinute: cursor, endMinute: cursor + b.minutes),
      );
      cursor += b.minutes;
    }
    return slots;
  }

  DayTemplate copyWith({
    String? name,
    int? startMinute,
    int? endMinute,
    List<DayBlock>? blocks,
  }) => DayTemplate(
    id: id,
    name: name ?? this.name,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    blocks: blocks ?? this.blocks,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'start': startMinute,
    'end': endMinute,
    'blocks': [for (final b in blocks) b.toJson()],
  };
}

/// Encode/decode the whole library to/from the JSON string we stash on the
/// Space's `day_templates` capability.
String encodeDayTemplates(List<DayTemplate> templates) =>
    jsonEncode([for (final t in templates) t.toJson()]);

List<DayTemplate> decodeDayTemplates(String? raw) {
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final t in decoded)
        if (t is Map<String, dynamic>) DayTemplate.fromJson(t),
    ];
  } on FormatException {
    return const [];
  }
}

/// Format minutes-from-midnight as a 12-hour clock label ("9:05 AM").
/// Pure (no BuildContext) so the model + tests can use it.
String clockLabel(int minutesFromMidnight) {
  final m = minutesFromMidnight % (24 * 60);
  final h24 = m ~/ 60;
  final min = m % 60;
  final period = h24 < 12 ? 'AM' : 'PM';
  final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
  final mm = min.toString().padLeft(2, '0');
  return '$h12:$mm $period';
}

/// "3h 15m" / "45m" — a friendly duration label.
String durationLabel(int minutes) {
  final m = minutes.abs();
  final h = m ~/ 60;
  final mm = m % 60;
  final sign = minutes < 0 ? '-' : '';
  if (h == 0) return '$sign${mm}m';
  if (mm == 0) return '$sign${h}h';
  return '$sign${h}h ${mm}m';
}
