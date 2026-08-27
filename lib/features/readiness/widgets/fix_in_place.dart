import 'dart:async';

import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/photos/photo_consent.dart';
import 'package:differentworld/features/readiness/readiness.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fix an attention item WHERE YOU FOUND IT.
///
/// Tapping "6 photo answers missing" used to land you on a child's record,
/// where you then had to find the consent control — so the app told you
/// about a problem and then made you go looking for its solution. For an
/// answer that is one tap of data ("yes/no", "no allergies"), navigating
/// anywhere is the whole cost of the task.
///
/// Only the items whose fix genuinely IS one control appear here. Taking a
/// photo needs a camera and an over-capacity room needs a decision about
/// children — those still route out, because pretending otherwise would put
/// a fake control in front of a real problem.
class FixInPlace extends ConsumerWidget {
  const FixInPlace({required this.item, super.key});

  final ReadinessItem item;

  /// Whether this kind can be resolved without leaving.
  static bool supports(ReadinessKind kind) =>
      kind == ReadinessKind.missingConsent ||
      kind == ReadinessKind.missingAllergyAnswer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    // The item names up to three children; resolve the FULL set so the fix
    // covers everyone it counted, not just the ones it had room to name.
    final targets = switch (item.kind) {
      ReadinessKind.missingConsent => [
        for (final s in subjects)
          if (recordedConsent(s) == PhotoConsent.unknown) s,
      ],
      ReadinessKind.missingAllergyAnswer => [
        for (final s in subjects)
          if ((s.allergies ?? '').trim().isEmpty) s,
      ],
      _ => const <Subject>[],
    };
    if (targets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in targets.take(8))
          _FixRow(key: ValueKey('fix-${s.id}'), subject: s, kind: item.kind),
        if (targets.length > 8)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              '${targets.length - 8} more on the roster',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _FixRow extends ConsumerWidget {
  const _FixRow({required this.subject, required this.kind, super.key});

  final Subject subject;
  final ReadinessKind kind;

  /// Both writes are UNDOABLE. These are one-tap controls where "No" sits a
  /// thumb-width from "Yes", and a consent answer set by accident is exactly
  /// the kind of silent wrong state this whole screen exists to surface.
  Future<void> _consent(
    BuildContext context,
    WidgetRef ref, {
    required bool allowed,
  }) async {
    final actions = ref.read(subjectCapActionsProvider);
    await writeWithUndo(
      messenger: ScaffoldMessenger.of(context),
      message: allowed
          ? '${subject.firstName} — photos allowed'
          : '${subject.firstName} — photos declined',
      onWrite: () => actions.setBoolCap(
        subjectId: subject.id,
        key: SubjectCaps.photoConsent,
        value: allowed,
      ),
      // Back to UNKNOWN, not to the opposite answer. Undoing "declined"
      // must not silently mean "allowed" — the state before the tap was
      // nobody having answered, and that is what has to come back.
      onUndo: () => actions.clearCap(
        subjectId: subject.id,
        key: SubjectCaps.photoConsent,
      ),
    );
  }

  Future<void> _noAllergies(BuildContext context, WidgetRef ref) async {
    // Messenger captured BEFORE the await — writeWithUndo reads it from the
    // context, and the DB future is a real async gap.
    final messenger = ScaffoldMessenger.of(context);
    final db = await ref.read(appDatabaseProvider.future);
    final previous = subject.allergies;
    await writeWithUndo(
      messenger: messenger,
      message: '${subject.firstName} — no allergies recorded',
      // "None" typed by a person is a real answer; blank is not. That
      // distinction is the whole reason this item exists, so the button
      // writes an explicit value rather than clearing the field.
      onWrite: () => db.subjectsDao.update_(id: subject.id, allergies: 'None'),
      onUndo: () =>
          db.subjectsDao.update_(id: subject.id, allergies: previous ?? ''),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              subject.firstName,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (kind == ReadinessKind.missingConsent) ...[
            TextButton(
              onPressed: () => unawaited(_consent(context, ref, allowed: true)),
              child: const Text('Yes'),
            ),
            TextButton(
              onPressed: () =>
                  unawaited(_consent(context, ref, allowed: false)),
              child: const Text('No'),
            ),
          ] else
            TextButton(
              onPressed: () => unawaited(_noAllergies(context, ref)),
              child: const Text('None'),
            ),
        ],
      ),
    );
  }
}
