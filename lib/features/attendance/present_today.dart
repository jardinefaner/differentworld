import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/attendance/attendance_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Who is actually in the room today.
///
/// Every live-room instrument needs this and three of them had written it
/// out separately — the arrangement engine, the fair picker, and the
/// ratio/capacity check — each re-deciding which attendance statuses count
/// as "here". Three copies of a rule is three chances to disagree about
/// whether `late` means present (it does).
///
/// **Falls back to the whole roster before anyone is marked.** A room where
/// attendance has not been taken yet is not an empty room, and treating it
/// as one would make every instrument refuse to work first thing in the
/// morning — exactly when they are wanted.
// ignore: specify_nonobvious_property_types
final presentSubjectsProvider = Provider.autoDispose
    .family<List<Subject>, String>((ref, groupId) {
      final roster =
          ref.watch(subjectsInGroupProvider(groupId)).value ??
          const <Subject>[];
      final records =
          ref
              .watch(
                attendanceForDayProvider((groupId: groupId, date: todayKey())),
              )
              .value ??
          const <AttendanceRecord>[];
      if (records.isEmpty) return roster;
      final away = {
        for (final r in records)
          if (!_isHere(r.status)) r.subjectId,
      };
      return [
        for (final s in roster)
          if (!away.contains(s.id)) s,
      ];
    });

/// `late` counts as here — a child who arrived at 3:20 is in the room.
bool _isHere(String status) => status == 'present' || status == 'late';
