import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/invites/invite_code.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/family/welcome_pdf.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/invites/invites_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

/// Gather + build + print/share the first-day welcome one-pager for a child
/// (docs/VISION.md). Staff action. Auto-fills from app data (program, cohort,
/// this week's world + dinner question, pickup); best-effort on the invite QR
/// — it creates a 30-day guardian invite if it can, and if that fails (no
/// capability / offline) the welcome still prints WITHOUT the QR, because the
/// rest of the page is the value.
Future<void> generateFirstDayWelcome(
  BuildContext context,
  WidgetRef ref,
  String subjectId,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final viewer = ref.read(viewerProvider);
  final subject = ref.read(subjectByIdProvider(subjectId)).value;
  if (subject == null) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Still loading this child — try again.')),
    );
    return;
  }
  final spaceId = viewer.spaceId;
  final programName = (viewer.space?.name ?? '').trim().isEmpty
      ? 'our program'
      : viewer.space!.name;

  // Cohort (room + age band).
  final groups = ref.read(groupsProvider).value ?? const <Group>[];
  Group? group;
  for (final g in groups) {
    if (g.id == subject.groupId) {
      group = g;
      break;
    }
  }

  // This week's curriculum world (drives the dinner question).
  final world = ref.read(currentWorldProvider);

  // Best-effort guardian invite → the family-app QR. Never blocks the page.
  String? inviteUrl;
  String? inviteCode;
  if (spaceId != null) {
    try {
      final invite = await ref.read(inviteActionsProvider).createGuardianInvite(
            spaceId: spaceId,
            subjectId: subjectId,
            expiry: InviteExpiry.thirtyDays,
            createdBy: viewer.memberId,
          );
      final code = invite.code;
      if (code != null && code.isNotEmpty) {
        inviteCode = code;
        inviteUrl = InviteCode.pagesLinkFor(code);
      }
    } on Object catch (e, st) {
      if (kDebugMode) debugPrint('[welcome] invite create failed: $e\n$st');
    }
  }

  final facts = <WelcomeFact>[
    if (group != null)
      (
        label: 'Room',
        value: [group.name, group.ageRange]
            .whereType<String>()
            .where((s) => s.trim().isNotEmpty)
            .join(' · '),
      ),
    if ((subject.pickupWindowEnd ?? '').trim().isNotEmpty)
      (label: 'Pickup by', value: _formatTime(subject.pickupWindowEnd!)),
  ];

  final bytes = await buildWelcomePdf(
    programName: programName,
    childFirstName: subject.firstName,
    facts: facts,
    worldName: world?.name,
    dinnerQuestion: world?.question,
    inviteUrl: inviteUrl,
    inviteCode: inviteCode,
  );

  await Printing.layoutPdf(
    onLayout: (_) => bytes,
    name: 'Welcome — ${subject.firstName}',
  );
}

/// "18:00" → "6:00 PM". Returns the input unchanged if it isn't HH:mm.
String _formatTime(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hhmm;
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}
