import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/onboarding/sample_child.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/shared/prefs_bool_notifier.dart';
import 'package:differentworld/shared/widgets/accent_edge_card.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The first-run starter spine — day one's Today, made undeniable
/// (docs/BRAND.md; docs/VISION.md dream #1).
///
/// Three cards that PROVE the app instead of touring it: put a game on
/// the TV (the room is alive before any data entry), open the sample
/// child's story (the year-end payoff, visible on day one), add the
/// first room (make it yours). Once a room exists, a closer card offers
/// the team/family invites. Each card retires itself when done; the
/// whole section disappears when everything is — no wizard, no coach
/// marks, nothing to skip (the instruction law: obvious first).
///
/// State lives in the space's capabilities JSON (synced — the spine
/// agrees across the director's devices); "room added" derives straight
/// from data. Teachers joining by invite get a one-card welcome instead,
/// dismissed per-device.

/// Pure spine state — derived, unit-testable, no Riverpod.
class SpineState {
  const SpineState({
    required this.castDone,
    required this.sampleSeen,
    required this.roomDone,
    required this.invitesDone,
    required this.dismissed,
    required this.sampleSubjectId,
  });

  factory SpineState.of(Capabilities caps, {required int groupCount}) {
    final sampleId = caps.getString(SpaceCaps.onboardingSampleSubjectId);
    return SpineState(
      castDone: caps.getBool(SpaceCaps.onboardingCastDone),
      // A removed sample counts as seen — the card just goes.
      sampleSeen:
          caps.getBool(SpaceCaps.onboardingSampleSeen) ||
          (sampleId == null || sampleId.isEmpty),
      roomDone: groupCount > 0,
      invitesDone: caps.getBool(SpaceCaps.onboardingInvitesDone),
      dismissed: caps.getBool(SpaceCaps.onboardingDismissed),
      sampleSubjectId: (sampleId == null || sampleId.isEmpty) ? null : sampleId,
    );
  }

  final bool castDone;
  final bool sampleSeen;
  final bool roomDone;
  final bool invitesDone;
  final bool dismissed;
  final String? sampleSubjectId;

  int get doneCount =>
      (castDone ? 1 : 0) + (sampleSeen ? 1 : 0) + (roomDone ? 1 : 0);

  /// The closer only exists once there's a room to invite people into.
  bool get showInvitesCloser => roomDone && !invitesDone;

  bool get allDone => castDone && sampleSeen && roomDone && !showInvitesCloser;

  bool get visible => !dismissed && !allDone;
}

/// Per-device flag for the teacher's one-card welcome.
class TeacherWelcomeDismissed extends PrefsBoolNotifier {
  @override
  String get prefsKey => 'onboarding_teacher_welcome_dismissed';

  @override
  bool get defaultValue => false;
}

final AsyncNotifierProvider<TeacherWelcomeDismissed, bool>
teacherWelcomeDismissedProvider =
    AsyncNotifierProvider<TeacherWelcomeDismissed, bool>(
      TeacherWelcomeDismissed.new,
    );

/// The section Today renders — full spine for directors, a one-card
/// welcome for joining staff, nothing once retired.
class StarterSpine extends ConsumerWidget {
  const StarterSpine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (viewer is GuardianViewer || !viewer.isSignedIn) {
      return const SizedBox.shrink();
    }
    if (!viewer.canManageSpace) return const _TeacherWelcome();

    final space = ref.watch(currentSpaceProvider).value;
    final groups = ref.watch(groupsProvider).value;
    if (space == null || groups == null) return const SizedBox.shrink();
    final state = SpineState.of(space.caps, groupCount: groups.length);
    if (!state.visible) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final gold = theme.extension<AppColors>()!.gold;

    Future<void> setCap(String key) =>
        ref.read(spaceCapActionsProvider).setCap(space.id, key, true);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Day one — everything below already works',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => unawaited(
                  setCap(SpaceCaps.onboardingDismissed),
                ),
                child: const Text('Hide setup'),
              ),
            ],
          ),
          if (state.castDone)
            const _DoneRow(label: 'A game hit the TV')
          else
            _SpineCard(
              accent: theme.colorScheme.primary,
              eyebrow: 'run something now',
              eyebrowIcon: Icons.cast_outlined,
              title: 'Put a game on the TV',
              body:
                  'This-or-That, riddles, reveal-the-picture — no setup, '
                  'works offline.',
              actionLabel: 'Cast a game',
              onTap: () {
                unawaited(setCap(SpaceCaps.onboardingCastDone));
                unawaited(context.push('/present'));
              },
            ),
          const SizedBox(height: 8),
          if (state.sampleSeen)
            const _DoneRow(label: 'You saw where the story goes')
          else
            _SpineCard(
              accent: gold,
              eyebrow: 'see where it goes',
              eyebrowIcon: Icons.auto_stories_outlined,
              title: 'Open the sample child’s book',
              body:
                  'Meet Sam — six weeks of captured moments, compiled into '
                  'a story. Your kids’ books start today.',
              actionLabel: 'See the story',
              onTap: state.sampleSubjectId == null
                  ? null
                  : () {
                      unawaited(setCap(SpaceCaps.onboardingSampleSeen));
                      unawaited(
                        context.push('/story/${state.sampleSubjectId}'),
                      );
                    },
              trailing: state.sampleSubjectId == null
                  ? null
                  : IconButton(
                      tooltip: 'Remove sample child',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => unawaited(
                        _removeSample(
                          context,
                          ref,
                          spaceId: space.id,
                          subjectId: state.sampleSubjectId!,
                        ),
                      ),
                    ),
            ),
          const SizedBox(height: 8),
          if (!state.roomDone)
            _SpineCard(
              accent: theme.colorScheme.secondary,
              eyebrow: 'make it yours',
              eyebrowIcon: Icons.meeting_room_outlined,
              title: 'Add your first room',
              body:
                  'A room, a few kids — or invite your team and let staff '
                  'add theirs.',
              actionLabel: 'Add a room',
              onTap: () => unawaited(context.push('/groups/new')),
            )
          else if (state.showInvitesCloser)
            _SpineCard(
              accent: theme.colorScheme.secondary,
              eyebrow: 'bring the others',
              eyebrowIcon: Icons.qr_code_2_outlined,
              title: 'Invite your team',
              body:
                  'Print a join code for staff — families get their own '
                  'welcome page from each child’s screen.',
              actionLabel: 'Open team invites',
              onTap: () {
                unawaited(setCap(SpaceCaps.onboardingInvitesDone));
                unawaited(context.push('/settings/team'));
              },
            )
          else
            const _DoneRow(label: 'Your first room is in'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: state.doneCount / 3,
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${state.doneCount} of 3 — this section retires itself',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _removeSample(
    BuildContext context,
    WidgetRef ref, {
    required String spaceId,
    required String subjectId,
  }) async {
    // Cascading (subject + six weeks of entries) — one re-insert can't
    // restore the tree, so this keeps the confirm wall.
    final ok = await confirmDestructive(
      context,
      title: 'Remove Sam?',
      message:
          'The sample child and all of Sam’s story go away. Your real '
          'kids’ stories are untouched.',
      confirmLabel: 'Remove',
    );
    if (!ok || !context.mounted) return;
    final db = await ref.read(appDatabaseProvider.future);
    await removeSampleChild(db, spaceId: spaceId, subjectId: subjectId);
  }
}

/// A completed step, collapsed to one calm line.
class _DoneRow extends StatelessWidget {
  const _DoneRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 18,
            color: theme.extension<AppColors>()!.growth,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpineCard extends StatelessWidget {
  const _SpineCard({
    required this.accent,
    required this.eyebrow,
    required this.eyebrowIcon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
    this.trailing,
  });

  final Color accent;
  final String eyebrow;
  final IconData eyebrowIcon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AccentEdgeCard(
      accent: accent,
      eyebrow: eyebrow,
      eyebrowIcon: eyebrowIcon,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: onTap,
            child: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

/// The invited teacher's first-run: one warm card, dismissed per-device.
class _TeacherWelcome extends ConsumerWidget {
  const _TeacherWelcome();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(teacherWelcomeDismissedProvider).value ?? true;
    if (dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AccentEdgeCard(
        accent: theme.colorScheme.primary,
        eyebrow: 'welcome',
        eyebrowIcon: Icons.waving_hand_outlined,
        children: [
          Text(
            'Your rooms are ready',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            'Today is home base: your kids, the schedule, and the '
            'capture bar below for anything worth remembering.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => unawaited(
                ref
                    .read(teacherWelcomeDismissedProvider.notifier)
                    .set(value: true),
              ),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }
}
