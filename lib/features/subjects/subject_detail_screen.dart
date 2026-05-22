import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/widgets/observation_form_sheet.dart';
import 'package:differentworld/features/exports/widgets/exports_list.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/subjects/widgets/alerts_section.dart';
import 'package:differentworld/features/subjects/widgets/attendance_strip.dart';
import 'package:differentworld/features/subjects/widgets/guardians_list.dart';
import 'package:differentworld/features/subjects/widgets/health_profile_card.dart';
import 'package:differentworld/features/subjects/widgets/observation_item.dart';
import 'package:differentworld/features/subjects/widgets/pickup_list.dart';
import 'package:differentworld/features/subjects/widgets/today_status_card.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Per-child timeline. Same screen for staff (reached via classroom →
/// student) and family (reached via Family Today → child card). The
/// viewer controls what's editable.
///
/// Sections, top to bottom:
/// - Header: avatar + name + age + classroom name + status today
/// - Alerts: allergies / IEP / medical conditions (the things you
///   want anyone to know before they touch the kid)
/// - Observations: full feed, newest first; FAB to add for canObserve
/// - Attendance: last ~60 days as colored dots
/// - Family: linked guardians, read-only for everyone but director
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({required this.subjectId, super.key});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);

    // Guardians can only see THEIR kids.
    if (viewer is GuardianViewer && !viewer.canSeeSubject(subjectId)) {
      return const EdgeScaffold(
        body: NoAccess(
          title: "That isn't one of your children.",
        ),
      );
    }

    final subjectAsync = ref.watch(subjectByIdProvider(subjectId));

    return EdgeScaffold(
      actions: [
        // Primary verb on the kid's detail screen is "Observation" —
        // the most-frequent action a teacher does here.
        if (viewer.canObserve && subjectAsync.value != null)
          PrimaryActionButton(
            tooltip: 'New observation',
            icon: Icons.add,
            onPressed: () => ObservationFormSheet.show(
              context,
              groupId: subjectAsync.value!.groupId ?? '',
              initialSubjectId: subjectId,
            ),
          ),
        if (viewer.canObserve && subjectAsync.value != null)
          SecondaryActionButton(
            tooltip: 'Progress report',
            icon: Icons.description_outlined,
            onPressed: () {
              final gid = subjectAsync.value!.groupId ?? '';
              if (gid.isEmpty) return;
              unawaited(
                context.push(
                  '/groups/$gid/students/$subjectId/progress-report',
                ),
              );
            },
          ),
        if (viewer.canManageSpace && subjectAsync.value != null)
          SecondaryActionButton(
            tooltip: 'Edit',
            icon: Icons.edit_outlined,
            onPressed: () {
              final gid = subjectAsync.value!.groupId ?? '';
              if (gid.isEmpty) return;
              unawaited(
                context.push('/groups/$gid/students/$subjectId/edit'),
              );
            },
          ),
        const SyncStatusIndicator(),
      ],
      body: subjectAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load',
          onRetry: () => ref.invalidate(subjectByIdProvider(subjectId)),
        ),
        data: (subject) {
          if (subject == null) {
            return const EmptyState(
              icon: Icons.search_off,
              title: 'Student not found.',
            );
          }
          return _SubjectBody(subject: subject, viewer: viewer);
        },
      ),
    );
  }
}

class _SubjectBody extends ConsumerWidget {
  const _SubjectBody({required this.subject, required this.viewer});

  final Subject subject;
  final Viewer viewer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final caps = Capabilities.fromJson(subject.capabilities);
    final fullName = '${subject.firstName} ${subject.lastName}';
    final groupId = subject.groupId;
    final groupAsync = groupId == null
        ? const AsyncValue<Group?>.data(null)
        : ref.watch(_groupForDetailProvider(groupId));
    final ageLine = _ageLine(subject.dob);
    final entriesAsync = ref.watch(
      entriesForSubjectProvider(
        (subjectId: subject.id, kind: EntryKind.observation),
      ),
    );

    final entries = entriesAsync.value ?? const <Entry>[];
    final totalObservations = entries.length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        // Today's status is hoisted ABOVE the identity row — emotional
        // context (what happened today?) first, identity (who am I
        // looking at) second. The back-button breadcrumb supplies the
        // name context until the eye reaches the bigger header.
        // (Shell reserves the chrome height; just breathing room here.)
        const SizedBox(height: 8),
        if (groupId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TodayStatusCard(subjectId: subject.id, groupId: groupId),
          ),

        // Identity row.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              PersonAvatar(
                name: fullName,
                photoUrl: subject.photoUrl,
                radius: 36,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: theme.textTheme.headlineSmall),
                    if (ageLine != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        ageLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (groupAsync.value != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        groupAsync.value!.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Section index chips: scroll-anchored quick links. Tap to
        // jump to a section. Lightweight; doesn't introduce slivers.
        const _SectionChips(),
        const SizedBox(height: 8),

        // Alerts (allergies / IEP / meds)
        AlertsSection(subject: subject, caps: caps),

        // Structured health profile — childcare-vertical only.
        // Storage layer is agnostic (subjects.capabilities JSONB);
        // other verticals would register their own intake card
        // here reading their own caps namespace.
        if (ref.watch(verticalLabelsProvider).vertical == 'childcare')
          HealthProfileCard(subject: subject),

        const _SectionGap(),
        // Quick-observation entry — a frictionless way to log a
        // one-line "how was Jane today?" without opening the heavier
        // observation form sheet. Only shown when the viewer can
        // observe.
        if (viewer.canObserve && groupId != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _QuickObservation(
              groupId: groupId,
              subjectId: subject.id,
            ),
          ),
        if (viewer.canObserve && groupId != null) const _SectionGap(),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Row(
            children: [
              Text('Observations', style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                entriesAsync.value == null
                    ? ''
                    : '$totalObservations',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        entriesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              'Could not load observations.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'No observations yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final e in entries.take(10))
                  SubjectObservationItem(entry: e),
                if (entries.length > 10)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.push('/observations'),
                        icon: const Icon(Icons.unfold_more, size: 16),
                        label: Text(
                          'View all ${entries.length}',
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Attendance — last 30 days',
            style: theme.textTheme.titleSmall,
          ),
        ),
        AttendanceStrip(subjectId: subject.id),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Family', style: theme.textTheme.titleSmall),
        ),
        GuardiansList(subjectId: subject.id),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Authorized for pickup',
            style: theme.textTheme.titleSmall,
          ),
        ),
        PickupList(subject: subject),

        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text(
            'Sent reports',
            style: theme.textTheme.titleSmall,
          ),
        ),
        ExportsListForSubject(subjectId: subject.id),

        // Notes always visible — placeholder when empty so the
        // director discovers the affordance instead of forgetting it
        // exists.
        const _SectionGap(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Notes', style: theme.textTheme.titleSmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Text(
            (subject.notes ?? '').isEmpty
                ? 'Anything to remember about ${subject.firstName}?'
                : subject.notes!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: (subject.notes ?? '').isEmpty
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
              fontStyle: (subject.notes ?? '').isEmpty
                  ? FontStyle.italic
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  static String? _ageLine(String? dobIso) {
    if (dobIso == null || dobIso.isEmpty) return null;
    final dob = DateTime.tryParse(dobIso);
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    var months = now.month - dob.month;
    if (now.day < dob.day) months -= 1;
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    if (years <= 0) return '$months months';
    if (months == 0) return '$years years';
    return '$years yr $months mo';
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _groupForDetailProvider =
    StreamProvider.autoDispose.family<Group?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.groupsDao.watchById(id);
  },
);

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 32);
}

/// Horizontal scroller of section anchors at the top of the detail
/// screen. We don't scroll-snap (that would require turning the body
/// into a sliver-with-keys); instead the chips serve as a visual TOC
/// and an affordance reminder of what's below.
class _SectionChips extends StatelessWidget {
  const _SectionChips();

  static const List<(String, IconData)> _items = [
    ('Alerts', Icons.health_and_safety_outlined),
    ('Observations', Icons.menu_book_outlined),
    ('Attendance', Icons.fact_check_outlined),
    ('Family', Icons.family_restroom_outlined),
    ('Pickup', Icons.directions_walk_outlined),
    ('Reports', Icons.picture_as_pdf_outlined),
    ('Notes', Icons.sticky_note_2_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final (label, icon) in _items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: Icon(icon, size: 16),
                label: Text(label, style: theme.textTheme.labelSmall),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

/// Friction-killer for observations. A single TextField that creates
/// an observation when submitted — no sheet, no photo upload, just a
/// fast text capture. Empty state nudges with the kid's first name.
class _QuickObservation extends ConsumerStatefulWidget {
  const _QuickObservation({required this.groupId, required this.subjectId});

  final String groupId;
  final String subjectId;

  @override
  ConsumerState<_QuickObservation> createState() =>
      _QuickObservationState();
}

class _QuickObservationState extends ConsumerState<_QuickObservation> {
  final _ctl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _ctl.text.trim();
    if (body.isEmpty || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(entryActionsProvider).createObservation(
            groupId: widget.groupId,
            subjectId: widget.subjectId,
            text: body,
          );
      if (!mounted) return;
      _ctl.clear();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Observation saved.')),
      );
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'subjects'),
      );
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not save.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctl,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Quick observation…',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => _save(),
            ),
          ),
          IconButton.filled(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            tooltip: 'Save observation',
          ),
        ],
      ),
    );
  }
}

/// In-card photo strip for the per-child timeline. One photo →
/// single full-width image. Multiple → horizontal scroll with a
/// "+N" pill on the first; tap any to open the fullscreen viewer
/// at that photo's index.

/// One guardian row inside the family list, with a "Message" trailing
/// affordance and an unread badge if this guardian has sent messages
/// staff hasn't read yet. Tap the chat icon to open the thread.

/// "Authorized for pickup" — non-guardian adults approved to collect
/// this child. Editable by guardians of the subject OR staff with
/// canAuthorizePickup; read-only for everyone else.
