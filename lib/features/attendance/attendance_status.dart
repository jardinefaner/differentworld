import 'package:flutter/material.dart';

/// Mirrors the `public.attendance_status` Postgres enum from migration 3.
/// String value sent to/from the DB matches the Postgres enum exactly.
enum AttendanceStatus {
  present,
  absent,
  late,
  earlyPickup,
  excused;

  /// Round-trip from DB string. Returns null on unknown values so a
  /// future server-side enum addition doesn't crash the client.
  static AttendanceStatus? fromDb(String? value) {
    if (value == null) return null;
    return switch (value) {
      'present' => AttendanceStatus.present,
      'absent' => AttendanceStatus.absent,
      'late' => AttendanceStatus.late,
      'early_pickup' => AttendanceStatus.earlyPickup,
      'excused' => AttendanceStatus.excused,
      _ => null,
    };
  }

  String get dbValue => switch (this) {
        AttendanceStatus.present => 'present',
        AttendanceStatus.absent => 'absent',
        AttendanceStatus.late => 'late',
        AttendanceStatus.earlyPickup => 'early_pickup',
        AttendanceStatus.excused => 'excused',
      };

  String get label => switch (this) {
        AttendanceStatus.present => 'Present',
        AttendanceStatus.absent => 'Absent',
        AttendanceStatus.late => 'Late',
        AttendanceStatus.earlyPickup => 'Early pickup',
        AttendanceStatus.excused => 'Excused',
      };

  IconData get icon => switch (this) {
        AttendanceStatus.present => Icons.check_circle,
        AttendanceStatus.absent => Icons.cancel_outlined,
        AttendanceStatus.late => Icons.schedule,
        AttendanceStatus.earlyPickup => Icons.directions_walk,
        AttendanceStatus.excused => Icons.medical_information_outlined,
      };

  Color color(ColorScheme scheme) => switch (this) {
        AttendanceStatus.present => scheme.primary,
        AttendanceStatus.absent => scheme.error,
        AttendanceStatus.late => scheme.tertiary,
        AttendanceStatus.earlyPickup => scheme.secondary,
        AttendanceStatus.excused => scheme.onSurfaceVariant,
      };
}
