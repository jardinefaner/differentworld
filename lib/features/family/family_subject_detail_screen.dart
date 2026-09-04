import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/entries/entries_providers.dart'
    show EntryKind;
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart'
    show Incident;
import 'package:differentworld/features/incidents/widgets/family_incident_card.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/l10n/app_localizations.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/hover_tap.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
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
    final l10n = AppLocalizations.of(context);
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
            onRetry: () => ref.invalidate(familySubjectByIdProvider(subjectId)),
          ),
          data: (subject) {
            if (subject == null) {
              return EmptyState(
                icon: Icons.help_outline,
                title: l10n.familyChildNotFound,
                message: "We couldn't load this profile. Pull to refresh.",
              );
            }
            // Defensive: a guardian who navigated to the wrong subject
            // shouldn't see anything sensitive. The router gate also
            // catches this, but layered defense is cheap.
            if (viewer is GuardianViewer && !viewer.canSeeSubject(subject.id)) {
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the same sections (over the same
    // family-scoped providers — privacy unchanged) re-lay as bento tiles; off
    // keeps the existing single-column feed. Re-layout only: every sub-widget,
    // provider, and tap is identical between the two paths.
    final bento = bentoEnabled(ref, perScreen: null);
    return bento ? _bentoBody(context) : _flatBody(context);
  }

  Widget _header(BuildContext context) {
    final fullName = '${subject.firstName} ${subject.lastName}'.trim();
    final age = _ageLabel(subject.dob);
    // Wave 64 reranking: the parent's first question is "is my kid OK
    // today?" — the answer leads. The ContentHeader shows the name + age +
    // a small trailing avatar so identity is confirmed without pushing the
    // day's status below the fold.
    return ContentHeader(
      title: fullName,
      subtitle: age,
      trailing: PersonAvatar(
        name: fullName,
        photoUrl: subject.photoUrl,
        radius: 22,
      ),
    );
  }

  /// The default layout — the single-column feed, ranked loudest-first.
  Widget _flatBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final horiz = constraints.maxWidth > 840 ? 48.0 : 16.0;
        return ListView(
          padding: EdgeInsets.fromLTRB(horiz, 0, horiz, 96),
          children: [
            _header(context),

            // -- Today (loudest) -----------------------------------------
            _SectionLabel(label: l10n.familyToday, theme: theme),
            _TodayCard(subject: subject),
            const SizedBox(height: 8),
            _TodayObservations(subjectId: subject.id),

            // -- Messages (next-most-important) --------------------------
            _SectionLabel(label: l10n.familyMessages, theme: theme),
            _MessagesCard(subjectId: subject.id),

            // -- Incidents (surfaced safety record; hides when none) -----
            _FamilyIncidents(subjectId: subject.id),

            // -- Recent observations (history) ---------------------------
            const SizedBox(height: 16),
            _SectionLabel(label: l10n.familyThisWeek, theme: theme),
            _RecentObservations(subjectId: subject.id),
          ],
        );
      },
    );
  }

  /// The bento variant — the SAME sections, re-weighted. The two SHORT status
  /// cards (today's check-in + messages) pair **2-up** via a [BentoGrid]
  /// (`phone: 1` → side-by-side on phone, half-width on tablet/desktop) so the
  /// answer to "is my kid OK today?" reads at a glance. The narrative +
  /// photo-hero feeds (today's notes, incidents, this week) are full-width —
  /// rendered as plain children rather than wide tiles so their observation
  /// text never truncates into a half-width column AND the self-suppressing
  /// incidents section contributes nothing (no forced min-height "empty band")
  /// when there's nothing to show.
  ///
  /// Each section keeps its label via [_BentoSection], a `mainAxisSize.min`
  /// column (no `Expanded` / `Spacer`; docs/GRID.md). Ordering matches the flat
  /// feed's priority: status pair → today's notes → incidents → this week.
  Widget _bentoBody(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ResponsivePage(
      children: [
        _header(context),
        const SizedBox(height: 8),
        // The grid IS the phone-density win: the two glanceable status cards
        // tile 2-up. Both default `tablet`/`desktop` to 2, so they stay a
        // clean half-and-half pair at every width.
        BentoGrid(
          tiles: [
            BentoTile(
              id: 'today',
              span: const BentoSpan(phone: 1),
              child: _BentoSection(
                label: l10n.familyToday,
                child: _TodayCard(subject: subject),
              ),
            ),
            BentoTile(
              id: 'messages',
              span: const BentoSpan(phone: 1),
              child: _BentoSection(
                label: l10n.familyMessages,
                child: _MessagesCard(subjectId: subject.id),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Narrative feeds stay full-width (text-heavy / photo heroes).
        _BentoSection(
          label: l10n.familyTodaysNotes,
          child: _TodayObservations(subjectId: subject.id),
        ),
        // Self-suppressing safety record — renders nothing when there are no
        // incidents, so no empty band appears (the reason it's a plain child,
        // not a wide tile with a forced cell min-height).
        _FamilyIncidents(subjectId: subject.id),
        const SizedBox(height: 16),
        _BentoSection(
          label: l10n.familyThisWeek,
          child: _RecentObservations(subjectId: subject.id),
        ),
      ],
    );
  }

  static String _ageLabel(String? dob) {
    if (dob == null || dob.isEmpty) return '';
    final dt = DateTime.tryParse(dob);
    if (dt == null) return '';
    final now = DateTime.now();
    final years = now.year - dt.year - (now.month < dt.month ? 1 : 0);
    if (years <= 0) {
      final months = (now.year - dt.year) * 12 + (now.month - dt.month);
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
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A bento-cell-safe wrapper: a [_SectionLabel] over its content in a
/// shrink-wrapping column. `mainAxisSize.min` is required because a bento cell
/// is min-height / unbounded-max (docs/GRID.md) — a default `.max` column with
/// no flex children wouldn't throw, but `.min` keeps the tile floor exactly the
/// content height and matches the established bento pattern. No `Expanded` /
/// `Spacer` here for the same reason.
class _BentoSection extends StatelessWidget {
  const _BentoSection({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(label: label, theme: theme),
        child,
      ],
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
        .watch(
          familyAttendanceForSubjectProvider(
            (subjectId: subject.id, dateIso: _todayIso),
          ),
        )
        .value;
    final status = myRecord == null
        ? null
        : AttendanceStatus.fromDb(myRecord.status);

    final statusColor =
        status?.color(theme.colorScheme) ?? theme.colorScheme.onSurfaceVariant;
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
    final entriesAsync = ref.watch(
      familyEntriesForSubjectProvider(
        (subjectId: subjectId, kind: EntryKind.observation),
      ),
    );
    final todays = (entriesAsync.value ?? const <Entry>[]).where((e) {
      final dt = DateTime.tryParse(e.recordedAt);
      return dt != null && !dt.isBefore(startOfDay);
    }).toList();

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
    final cutoff = DateTime(now.year, now.month, now.day - 7);
    final entriesAsync = ref.watch(
      familyEntriesForSubjectProvider(
        (subjectId: subjectId, kind: EntryKind.observation),
      ),
    );
    final today = DateTime(now.year, now.month, now.day);
    final recent = (entriesAsync.value ?? const <Entry>[]).where((e) {
      final dt = DateTime.tryParse(e.recordedAt);
      if (dt == null) return false;
      // Older than today, newer than 7 days ago.
      return dt.isBefore(today) && dt.isAfter(cutoff);
    }).toList();

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

/// Family-facing incidents this child's staff have surfaced (notified or
/// noted). Renders nothing at all when there are none, so the section
/// only appears when there's something to show. Leak-proof: each card is
/// a [FamilyIncidentCard], which never reads the internal narrative.
class _FamilyIncidents extends ConsumerWidget {
  const _FamilyIncidents({required this.subjectId});
  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // W2: honor the program kill-switch — if the director turned incident
    // reports off, the family section disappears too.
    if (!ref.watch(viewerProvider).featureIncidentReports) {
      return const SizedBox.shrink();
    }
    final async = ref.watch(familyIncidentsForSubjectProvider(subjectId));
    // W4: a fetch failure must not look identical to "no incidents" — a
    // guardian could miss real safety info. Surface a quiet note instead
    // of silently hiding.
    if (async.hasError) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _SectionLabel(label: l10n.familyIncidents, theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Could not load incident history. Pull to refresh.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
    final incidents = async.value ?? const <Incident>[];
    if (incidents.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _SectionLabel(label: l10n.familyIncidents, theme: theme),
        for (final i in incidents) FamilyIncidentCard(incident: i),
      ],
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    // Defense-in-depth (Red Team B2): this card renders `entry.body`
    // raw, which is family-safe ONLY for observations. If a non-
    // observation kind (e.g. an incident, whose narrative can name other
    // children) ever reaches here, render nothing rather than leak it.
    if (entry.kind != EntryKind.observation) return const SizedBox.shrink();
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
              child: HoverTap(
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
    final messagesAsync = ref.watch(
      messageThreadProvider(
        (subjectId: subjectId, guardianId: guardianId),
      ),
    );
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
              onPressed: () => context.push('/messages/$subjectId/$guardianId'),
              icon: const Icon(Icons.forum_outlined),
              label: Text(hasMessages ? 'Open thread' : 'Start a thread'),
            ),
          ),
        ],
      ),
    );
  }
}
