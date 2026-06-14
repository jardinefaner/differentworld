import 'dart:async';

import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Snap a child's paper into their cumulative work (docs/VISION.md "writing
/// their answers on paper, cumulative"). One tap: camera (or gallery off
/// mobile) → offline-safe upload → a `work_sample` entry tagged to today's
/// world/day.
///
/// Offline-safe by the CLAUDE.md attachment-id contract: the attachment id is
/// pre-generated and passed to BOTH `uploadOnly(entityId:)` AND
/// `createWorkSample(photoIds:)`, so a deferred offline upload patches the
/// right row instead of silently losing the photo.
Future<void> snapWork(
  BuildContext context,
  WidgetRef ref, {
  required String subjectId,
  required String groupId,
  required String subjectName,
}) async {
  // Capture context-dependent handles BEFORE the first await.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final service = ref.read(photoServiceProvider);
  // Camera on mobile; a file/gallery pick everywhere else (no in-app camera
  // off-mobile — docs/PLATFORM_RUBRIC.md P1).
  final source = isMobileCapturePlatform ? ImageSource.camera : ImageSource.gallery;
  final picked = await service.pickPhoto(source);
  if (picked == null) return;

  unawaited(HapticFeedback.mediumImpact());
  final attId = const Uuid().v4();
  try {
    final url = await service.uploadOnly(
      entityKind: 'attachment',
      entityId: attId,
      picked: picked,
    );
    final world = ref.read(currentWorldProvider);
    final day = ref.read(currentProgramDayProvider);
    await ref.read(entryActionsProvider).createWorkSample(
          subjectId: subjectId,
          groupId: groupId,
          photoUrls: [url],
          photoIds: [attId],
          worldId: world?.id,
          day: day,
        );
    messenger?.showSnackBar(
      SnackBar(content: Text("Saved to $subjectName's work")),
    );
  } on Object catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: 'work_sample'),
    );
    messenger?.showSnackBar(
      const SnackBar(content: Text("Couldn't save that photo. Try again.")),
    );
  }
}
