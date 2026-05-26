import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/entries/entries_providers.dart' show EntryKind;
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/route_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Family-side per-child screen. A simpler, read-only feed of "what
/// my kid did today" — no admin chrome, no editing affordances.
///
/// Routed at `/children/:sid` when the active viewer is a
/// [GuardianViewer]. Staff hitting the same route get redirected
/// to the regular SubjectDetailScreen because their lens needs the
/// admin surface.
class FamilySubjectDetailScreen extends ConsumerWidget {
  const FamilySubjectDetailScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final subjectAsync = ref.watch(familySubjectByIdProvider(subjectId));
    // Wave 113: dynamic tab title — the child's name. Falls back
    // to "Child" while loading.
    final childName = subjectAsync.value == null
        ? 'Child'
        : '${subjectAsync.value!.firstName} ${subjectAsync.value!.lastName}'
            .trim();

    return RouteTitle(
      title: childName.isEmpty ? 'Child' : childName,
      child: EdgeScaffold(
      actions: const [SyncStatusIndicator()],
      body: subjectAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load',
          onRetry: () =>
              ref.invalidate(familySubjectByIdProvider(subjectId)),
        ),
        data: (subject) {
          if (subject == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'Child not found',
              message: "We couldn't load this profile. Pull to refresh.",
            );
          }
          // Defensive: a guardian who navigated to the wrong subject
          // shouldn't see anything sensitive. The router gate also
          // catches this, but layered defense is cheap.
          if (viewer is GuardianViewer &&
              !viewer.canSeeSubject(subject.id)) {
            return const EmptyState(
              icon: Icons.lock_outline,
              title: 'Not available',
            );
          }
          return _FamilyDetailBody(subject: subject);
        },
      ),
    ),
    );
  }
}

class _FamilyDetailBody extends ConsumerWidget {
  const _FamilyDetailBody({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fullName = '${subject.firstName} ${subject.lastName}'.trim();
    final age = _ageLabel(subject.dob);

    return LayoutBuilder(
      builder: (context, constraints) {
        final horiz = constraints.maxWidth > 840 ? 48.0 : 16.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(horiz, 0, horiz, 96),
          children: [
            // Wave 64 reranking: the parent's first question is
            // "is my kid OK today?" — the answer leads. The big
            // avatar that used to dominate the top is gone; the
            // ContentHeader still shows the name + age + a small
            // trailing avatar so identity is confirmed without
            // pushing the day's status below the fold.
            ContentHeader(
              title: fullName,
              subtitle: age,
              trailing: PersonAvatar(
                name: fullName,
                photoUrl: subject.photoUrl,
                radius: 22,
              ),
            ),

            // -- Today (loudest) -----------------------------------------
            _SectionLabel(label: 'Today', theme: theme),
            _TodayCard(subject: subject),
            const SizedBox(height: 8),
            _TodayObservations(subjectId: subject.id),

            // -- Messages (next-most-important) --------------------------
            _SectionLabel(label: 'Messages', theme: theme),
            _MessagesCard(subjectId: subject.id),

            // -- Recent observations (history) ---------------------------
            const SizedBox(height: 16),
            _SectionLabel(label: 'This week', theme: theme),
            _RecentObservations(subjectId: subject.id),
          ],
        );
      },
    );
  }

  static String _ageLabel(String? dob) {
    if (dob == null || dob.isEmpty) return '';
    final dt = DateTime.tryParse(dob);
    if (dt == null) return '';
    final now = DateTime.now();
    final years = now.year - dt.year - (now.month < dt.month ? 1 : 0);
    if (years <= 0) {
      final months = (now.year - dt.year) * 12 +
          (now.month - dt.month);
      return '$months months old';
    }
    return '$years years old';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.theme});
  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Today's check-in status. Mirrors the chip in FamilyTodayScreen but
/// without the navigation affordance — we're already on the detail.
class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.subject});
  final Subject subject;

  String get _todayIso => todayKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myRecord = ref
        .watch(familyAttendanceForSubjectProvider(
          (subjectId: subject.id, dateIso: _todayIso),
        ))
        .value;
    final status =
        myRecord == null ? null : AttendanceStatus.fromDb(myRecord.status);

    final statusColor = status?.color(theme.colorScheme) ??
        theme.colorScheme.onSurfaceVariant;
    final notes = myRecord?.notes;
    return FeatureCard(
      padding: const EdgeInsets.all(16),
      leading: Icon(
        status?.icon ?? Icons.schedule,
        color: statusColor,
        size: 32,
      ),
      title: Text(
        status?.label ?? 'Not yet checked in today',
        style: theme.textTheme.titleMedium?.copyWith(
          color: statusColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: notes != null && notes.isNotEmpty ? notes : null,
    );
  }
}

class _TodayObservations extends ConsumerWidget {
  const _TodayObservations({required this.subjectId});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final entriesAsync = ref.watch(familyEntriesForSubjectProvider(
      (subjectId: subjectId, kind: EntryKind.observation),
    ));
    final todays = (entriesAsync.value ?? const <Entry>[])
        .where((e) {
          final dt = DateTime.tryParse(e.recordedAt);
          return dt != null && !dt.isBefore(startOfDay);
        })
        .toList();

    if (todays.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No notes from today yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in todays)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ObservationCard(entry: e),
          ),
      ],
    );
  }
}

class _RecentObservations extends ConsumerWidget {
  const _RecentObservations({required this.subjectId});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final cutoff =
        DateTime(now.year, now.month, now.day - 7);
    final entriesAsync = ref.watch(familyEntriesForSubjectProvider(
      (subjectId: subjectId, kind: EntryKind.observation),
    ));
    final today = DateTime(now.year, now.month, now.day);
    final recent = (entriesAsync.value ?? const <Entry>[])
        .where((e) {
          final dt = DateTime.tryParse(e.recordedAt);
          if (dt == null) return false;
          // Older than today, newer than 7 days ago.
          return dt.isBefore(today) && dt.isAfter(cutoff);
        })
        .toList();

    if (recent.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Nothing from earlier this week.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in recent)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ObservationCard(entry: e),
          ),
      ],
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = entry.body;
    final photoUrl = entry.photoUrl;
    final when = DateTime.tryParse(entry.recordedAt)?.toLocal();
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photoUrl != null && photoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => PhotoViewer.open(context, urls: [photoUrl]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: PersonPhotoNetwork(
                      urlOrPath: photoUrl,
                      placeholderBuilder: (_) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHigh,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (body != null && body.isNotEmpty)
            Text(body, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            relativeTimeAgo(when),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Family-side messages preview: shows the latest message (if any)
/// and a button to open the thread. Guardian-only — the viewer must
/// be a [GuardianViewer] to render this card.
class _MessagesCard extends ConsumerWidget {
  const _MessagesCard({required this.subjectId});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    if (viewer is! GuardianViewer) {
      // Staff hitting /children/:sid shouldn't normally reach here
      // (they use the staff route), but defensively render nothing.
      return const SizedBox.shrink();
    }
    final guardianId = viewer.guardian.id;
    final messagesAsync = ref.watch(messageThreadProvider(
      (subjectId: subjectId, guardianId: guardianId),
    ));
    final messages = messagesAsync.value ?? const <Message>[];
    final lastFromStaff = messages.lastWhere(
      (m) => m.senderKind == MessageSenderKind.staff,
      orElse: () => const Message(
        id: '',
        spaceId: '',
        subjectId: '',
        guardianId: '',
        senderKind: '',
        body: '',
        // Empty JSON array — no guardian has read this placeholder.
        readByGuardianIds: '[]',
        createdAt: '',
      ),
    );
    final hasMessages = messages.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasMessages && lastFromStaff.id.isNotEmpty) ...[
            Text(
              lastFromStaff.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'From your teacher · ${relativeTimeAgo(
                DateTime.tryParse(lastFromStaff.createdAt)?.toLocal(),
              )}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ] else
            Text(
              'No messages yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () =>
                  context.push('/messages/$subjectId/$guardianId'),
              icon: const Icon(Icons.forum_outlined),
              label: Text(hasMessages ? 'Open thread' : 'Start a thread'),
            ),
          ),
        ],
      ),
    );
  }
}
