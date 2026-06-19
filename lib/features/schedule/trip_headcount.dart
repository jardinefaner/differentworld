import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The legs of a field-trip headcount, in order. Each leg is a roll-call: is
/// every kid accounted for before the group moves?
class TripLeg {
  const TripLeg._();

  static const String departure = 'departure';
  static const String atDestination = 'at_destination';
  static const String returnLeg = 'return';

  static const List<String> ordered = [departure, atDestination, returnLeg];

  static String label(String leg) => switch (leg) {
    departure => 'Departure',
    atDestination => 'Arrived at destination',
    returnLeg => 'Return',
    _ => leg,
  };

  static String sublabel(String leg, String destination) {
    final dest = destination.trim().isEmpty ? 'the destination' : destination;
    return switch (leg) {
      departure => 'Program → $dest',
      atDestination => 'Off the bus',
      returnLeg => '$dest → program',
      _ => '',
    };
  }
}

/// The latest headcount recorded for one leg, parsed from a `trip_headcount`
/// entry's payload.
class TripHeadcountLeg {
  const TripHeadcountLeg({
    required this.leg,
    required this.present,
    required this.expected,
    required this.takenAt,
    this.overrideReason,
    this.overrideHolder,
  });

  final String leg;
  final Set<String> present;
  final int expected;
  final DateTime? takenAt;
  final String? overrideReason;
  final String? overrideHolder;

  int get count => present.length;
  bool get allPresent => expected > 0 && count >= expected;

  /// A leg is settled either when everyone's accounted for OR a deliberate
  /// override (someone left in another adult's care) was logged with a reason.
  bool get done =>
      allPresent || (overrideReason != null && overrideReason!.isNotEmpty);
}

/// The latest headcount per leg for a trip block, parsed from the append-only
/// `trip_headcount` entries. Built on [momentsForBlockProvider] (entries for
/// the block, newest-first) so it's offline-first + reactive; the first entry
/// seen per leg is the current count.
// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final tripHeadcountsProvider = Provider.autoDispose
    .family<Map<String, TripHeadcountLeg>, String>(
      (ref, blockId) {
        final entries =
            ref.watch(momentsForBlockProvider(blockId)).value ??
            const <Entry>[];
        final byLeg = <String, TripHeadcountLeg>{};
        for (final e in entries) {
          if (e.kind != EntryKind.tripHeadcount) continue;
          final Map<String, dynamic> d;
          try {
            d = jsonDecode(e.details) as Map<String, dynamic>;
          } on Object catch (_) {
            continue;
          }
          final leg = d['leg'] as String?;
          if (leg == null || byLeg.containsKey(leg)) continue; // newest wins
          final present = (d['present'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<String>()
              .toSet();
          byLeg[leg] = TripHeadcountLeg(
            leg: leg,
            present: present,
            expected: (d['expected'] as num?)?.toInt() ?? present.length,
            takenAt: DateTime.tryParse(e.recordedAt)?.toLocal(),
            overrideReason: d['override_reason'] as String?,
            overrideHolder: d['override_holder'] as String?,
          );
        }
        return byLeg;
      },
    );
