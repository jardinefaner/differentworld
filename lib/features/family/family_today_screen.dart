import 'dart:async';
import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
// `entries_providers.dart` is imported for `EntryKind` constants only —
// the per-subject reads route through `family_providers.dart` because
// the local Drift mirror is empty for guardians (see file header there).
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/exports/exports_providers.dart';
import 'package:differentworld/features/exports/signed_export_url.dart';
import 'package:differentworld/features/family/family_providers.dart';
// `attachments_providers.dart` is imported for the `AttachmentsX`
// `.urls` / `.thumbUrls` extension; the read itself goes via
// `familyAttachmentsForEntityProvider`.
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/recap/recap_model.dart';
import 'package:differentworld/features/schedule/widgets/now_next_strip.dart';
import 'package:differentworld/features/settings/widgets/text_size_tile.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:differentworld/shared/widgets/status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Family-side home screen. Shown when the active viewer is a
/// [GuardianViewer]. Lists the guardian's children with today's
/// status; no staff surface, no admin chrome.
///
/// Minimum viable for this wave — per-child timeline, messaging,
/// billing surfaces are documented in the family-login skill as
/// follow-up work.
class FamilyTodayScreen extends ConsumerWidget {
  const FamilyTodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (viewer is! GuardianViewer) {
      // Router is supposed to gate; defensive empty state.
      return const EdgeScaffold(body: SizedBox.shrink());
    }
    final space = viewer.space;
    final childrenAsync = ref.watch(familyChildrenProvider);

    return EdgeScaffold(
      showBack: false,
      actions: [
        // Guardians never reach `/settings`, but Helen-persona accounts
        // still need the in-app text-size override (the OS slider alone
        // isn't enough — see persona-audit 2026-05-23). One tap opens
        // the shared text-size sheet used by staff Settings; no new
        // route, no guardian-only Settings screen needed. We pass the
        // enclosing `ref` directly — FamilyTodayScreen is already a
        // ConsumerWidget, so a nested Consumer just for the ref would
        // be redundant.
        IconButton(
          tooltip: 'Display settings',
          icon: const Icon(Icons.format_size_outlined),
          onPressed: () => showTextSizePicker(context, ref),
        ),
        const SyncStatusIndicator(),
      ],
      body: childrenAsync.when(
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
        error: (_, _) => ErrorState(
          title: 'Could not load',
          onRetry: () => ref.invalidate(familyChildrenProvider),
        ),
        data: (children) {
          if (children.isEmpty) {
            return const EmptyState(
              icon: Icons.child_care_outlined,
              title: 'No children linked yet',
              // Wave 96: dropped the "check back in a few minutes"
              // promise — linking children often happens days
              // before the program starts, and a parent who came
              // back the next day shouldn't think the app is
              // broken. Now: just say what will happen, without
              // pretending we know when.
              message:
                  "Your program director hasn't linked your children yet. "
                  "Once they do, your child's daily updates will appear here.",
            );
          }
          return _FamilyTodayList(
            space: space,
            children: children,
            guardianName: viewer.displayName,
          );
        },
      ),
    );
  }
}

class _FamilyTodayList extends ConsumerWidget {
  const _FamilyTodayList({
    required this.space,
    required this.children,
    required this.guardianName,
  });

  final Space? space;
  final List<Subject> children;
  final String guardianName;

  String get _todayIso => todayKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Flag-first subtitle: warmer voice when everyone's accounted for,
    // an actionable line when at least one of "your kids" is flagged.
    // Reads each kid's row via the family per-subject PostgREST provider
    // (the staff-side `attendanceForDayProvider` is per-group + reads
    // local Drift, which is empty for guardians).
    final flagged = <Subject>[];
    for (final c in children) {
      final myRecord = ref
          .watch(familyAttendanceForSubjectProvider(
            (subjectId: c.id, dateIso: _todayIso),
          ))
          .value;
      if (myRecord == null) continue;
      final s = AttendanceStatus.fromDb(myRecord.status);
      if (s == AttendanceStatus.late || s == AttendanceStatus.absent) {
        flagged.add(c);
      }
    }

    return ResponsivePage(
      children: [
        ContentHeader(
          title: space?.name ?? 'Today',
          subtitle: _subtitle(guardianName: guardianName, flagged: flagged),
          subtitleColor:
              flagged.isEmpty ? null : Theme.of(context).colorScheme.error,
        ),
        // Marcus-persona "30-second check" summary — one sentence
        // that closes the loop without parsing each card. Reads
        // either "All accounted for · Pickup in 3h" (calm) or
        // "{kid} needs your attention" (action-mode).
        _SummarySentence(children: children, flagged: flagged),
        const SizedBox(height: 12),
        // Recent progress reports the staff have sent the guardian.
        // Renders nothing when the inbox is empty so it never adds
        // chrome on a quiet day. Closes the last Tier-B item from
        // the 2026-05-23 persona-audit (Lauren / Devon / Helen /
        // Marcus). Subjects-by-id is computed here once so the
        // card can label each report with the kid's first name.
        _ReceivedReportsCard(
          subjectsById: {for (final c in children) c.id: c},
        ),
        for (final child in children) ...[
          _ChildCard(child: child),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  static String _subtitle({
    required String guardianName,
    required List<Subject> flagged,
  }) {
    if (flagged.isNotEmpty) {
      final names = flagged.map((c) => c.firstName).join(' & ');
      return '$names — check the card below';
    }
    final greeting = _greetingForTime(DateTime.now());
    final dayLabel = DateFormat.yMMMMEEEEd().format(DateTime.now());
    if (guardianName.isEmpty) return '$greeting · $dayLabel';
    return '$greeting, $guardianName · $dayLabel';
  }

  static String _greetingForTime(DateTime when) {
    final hour = when.hour;
    if (hour < 5) return 'Hi';
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({required this.child});

  final Subject child;

  String get _todayIso => todayKey();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final myRecord = ref
        .watch(familyAttendanceForSubjectProvider(
          (subjectId: child.id, dateIso: _todayIso),
        ))
        .value;
    final status = myRecord == null
        ? null
        : AttendanceStatus.fromDb(myRecord.status);

    final flagged = status == AttendanceStatus.late ||
        status == AttendanceStatus.absent;

    // Status label, coloured by state — grey "Check-in pending", the
    // status colour otherwise. Shared by both presentations.
    final statusLine = Text(
      _statusLabel(status),
      style: theme.textTheme.bodySmall?.copyWith(
        color: status == null ? scheme.onSurfaceVariant : status.color(scheme),
        fontWeight: flagged ? FontWeight.w600 : null,
      ),
    );

    // Below-the-header content — identical in both presentations.
    final below = <Widget>[
      // Lauren persona's most-anticipated surface — the most recent
      // observation photo from today, so the family sees the kid's day
      // before reading anything.
      _PhotoOfTheMomentPeek(subjectId: child.id),
      // Today's recap — the room's shared day + this child's own moments,
      // sent by staff. Renders nothing until today's recap is sent, so the
      // card stays tight on a quiet morning. Already scrubbed of other
      // children's names at compose time (see recap_model.dart).
      _TodaysRecapPeek(subjectId: child.id),
      // "What's my kid doing right now / next?" Renders nothing if the
      // cohort has no schedule today, so the card stays tight.
      if (child.groupId != null) ...[
        const SizedBox(height: 10),
        NowNextStrip(groupId: child.groupId!, compact: true),
      ],
      // "Has my child been picked up?" Renders only once released; its
      // silence is itself the "still here" signal.
      _PickupStatusLine(subjectId: child.id),
    ];

    // Neutral → a flush one-edge row (calm-aware via FeatureCard): the
    // child's face hangs in the shared gutter, name + status on the text
    // edge, photo / schedule / pickup flush below. Same vocabulary as the
    // staff Today rows so the two lenses read as one system.
    if (!flagged) {
      return FeatureCard(
        title: '${child.firstName} ${child.lastName}',
        onTap: () => context.push('/children/${child.id}'),
        leading: PersonAvatar(
          name: '${child.firstName} ${child.lastName}',
          photoUrl: child.photoUrl,
        ),
        // One-tap "message staff" shortcut to the per-child thread
        // (/messages/:subjectId/:guardianId — the shape the detail
        // screen uses). Pinned to the row's right.
        trailing: _MessageStaffButton(subjectId: child.id),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${child.firstName} ${child.lastName}',
              style: theme.textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            statusLine,
            ...below,
          ],
        ),
      );
    }

    // Flagged (late / absent) → keep the tinted SIGNAL card: coloured fill
    // + border so it's unmissable at a glance. The brand law keeps signals
    // tinted; only neutral chrome flattens.
    return Card(
      clipBehavior: Clip.antiAlias,
      color: status!.color(scheme).withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: status.color(scheme).withValues(alpha: 0.45),
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/children/${child.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  // Traffic-light scan affordance — same vocabulary as
                  // staff Today so the family lens reads consistently.
                  // Decorative → excluded from semantics (the status line
                  // already speaks the state).
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: ExcludeSemantics(
                      child: StatusDot(kind: StatusDotKind.needsAttention),
                    ),
                  ),
                  PersonAvatar(
                    name: '${child.firstName} ${child.lastName}',
                    photoUrl: child.photoUrl,
                    radius: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${child.firstName} ${child.lastName}',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        statusLine,
                      ],
                    ),
                  ),
                  _MessageStaffButton(subjectId: child.id),
                  const SizedBox(width: 4),
                  Icon(status.icon, color: status.color(scheme)),
                ],
              ),
              ...below,
            ],
          ),
        ),
      ),
    );
  }

  /// Reassuring copy on the calm path — guardians often check this
  /// screen in the morning anxious before drop-off lands; lead with the
  /// usual time, not an accusatory "not yet."
  static String _statusLabel(AttendanceStatus? s) {
    if (s == null) return 'Check-in pending — usually before 9 AM';
    return s.label;
  }
}

/// The family-side pickup confirmation: "Picked up at 4:47 PM" (or "Left early
/// today"). Renders nothing until the child has actually been released — its
/// absence is itself the "still here" signal, which the attendance status on
/// the card already conveys.
class _PickupStatusLine extends ConsumerWidget {
  const _PickupStatusLine({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(familyPickupStatusProvider(subjectId)).value;
    if (status == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (IconData icon, String text, Color tint) = switch (status.state) {
      FamilyPickupState.releasedAt => (
        Icons.check_circle_outline,
        status.at != null ? 'Picked up at ${timeOfDay(status.at!)}' : 'Picked up',
        scheme.primary,
      ),
      FamilyPickupState.leftEarly => (
        Icons.logout_outlined,
        'Left early today',
        scheme.tertiary,
      ),
      // here / absent / unknown → no line (the status text covers it).
      _ => (Icons.circle, '', scheme.onSurfaceVariant),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: tint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Message staff" icon button on each child card. Pulled out as its
/// own ConsumerWidget so the surrounding `_ChildCard.build()` doesn't
/// have to read the viewer just to construct one tap target — and so
/// the route shape lives in one place (matches the per-child thread
/// route shape `/messages/:subjectId/:guardianId`).
class _MessageStaffButton extends ConsumerWidget {
  const _MessageStaffButton({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    final guardianId = viewer is GuardianViewer ? viewer.guardian.id : null;
    return IconButton.filledTonal(
      tooltip: 'Message staff',
      icon: const Icon(Icons.forum_outlined),
      // If the viewer isn't a guardian (staff impersonating a family
      // surface in dev, e.g.) we can't build a valid thread URL —
      // disable the button rather than push a broken route.
      onPressed: guardianId == null
          ? null
          : () => context.push('/messages/$subjectId/$guardianId'),
    );
  }
}

/// The "30-second check" summary band at the top of Family Today —
/// answers "is everything fine?" in one sentence so a parent in a
/// meeting can close the app in 4 seconds without parsing each kid's
/// card. Renders error-tinted when something needs attention.
class _SummarySentence extends ConsumerWidget {
  const _SummarySentence({
    required this.children,
    required this.flagged,
  });

  final List<Subject> children;
  final List<Subject> flagged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Pickup-soon heuristic: surface the nearest upcoming pickup window
    // when we're within ~4 hours of it. Reads each kid's window;
    // picks the earliest still-future end_time.
    final now = DateTime.now();
    DateTime? nearestPickup;
    Subject? nearestKid;
    for (final c in children) {
      final raw = c.pickupWindowEnd ?? c.pickupWindowStart;
      if (raw == null || raw.isEmpty) continue;
      final parts = raw.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h == null || m == null) continue;
      final candidate =
          DateTime(now.year, now.month, now.day, h, m);
      if (candidate.isBefore(now)) continue;
      if (nearestPickup == null || candidate.isBefore(nearestPickup)) {
        nearestPickup = candidate;
        nearestKid = c;
      }
    }

    final sentence = _composeSentence(
      flagged: flagged,
      children: children,
      nearestPickup: nearestPickup,
      nearestKid: nearestKid,
      now: now,
    );

    final hasFlag = flagged.isNotEmpty;
    final container = hasFlag
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    final onContainer = hasFlag
        ? scheme.onErrorContainer
        : scheme.onSurface;
    final icon = hasFlag
        ? Icons.priority_high_rounded
        : Icons.check_circle_outline;

    return Material(
      color: container,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Icon(icon, color: onContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sentence,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: onContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _composeSentence({
    required List<Subject> flagged,
    required List<Subject> children,
    required DateTime? nearestPickup,
    required Subject? nearestKid,
    required DateTime now,
  }) {
    if (flagged.isNotEmpty) {
      if (flagged.length == 1) {
        return '${flagged.first.firstName} needs your attention.';
      }
      final names = flagged.map((c) => c.firstName).join(' & ');
      return '$names need your attention.';
    }
    // Calm path — quantify accountability + nearest pickup.
    final countLabel = children.length == 1
        ? 'Your child is'
        : 'All ${children.length} are';
    if (nearestPickup != null && nearestKid != null) {
      final diff = nearestPickup.difference(now);
      String when;
      if (diff.inMinutes < 60) {
        when = '${diff.inMinutes} min';
      } else if (diff.inHours < 6) {
        final h = diff.inHours;
        final m = diff.inMinutes - h * 60;
        when = m == 0 ? '${h}h' : '${h}h ${m}m';
      } else {
        when = timeOfDay(nearestPickup);
      }
      if (children.length == 1) {
        return '$countLabel accounted for · pickup in $when';
      }
      return '$countLabel accounted for · ${nearestKid.firstName} pickup '
          'in $when';
    }
    return '$countLabel accounted for.';
  }
}

/// "Photo of the moment" peek inside the child card. Surfaces the
/// most recent observation photo from TODAY so a parent checking
/// the family Today screen sees their kid's day before they read
/// any text.
///
/// Renders nothing when:
///   - There's no observation for this child today
///   - The most-recent observation has no attached photos
///
/// Lauren persona — opens the app at 11 AM during a coffee break,
/// wants the warmest possible "what's my kid up to" signal in one
/// glance.
class _PhotoOfTheMomentPeek extends ConsumerWidget {
  const _PhotoOfTheMomentPeek({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(
      familyEntriesForSubjectProvider(
        (subjectId: subjectId, kind: EntryKind.observation),
      ),
    );
    final entries = entriesAsync.value ?? const <Entry>[];
    if (entries.isEmpty) return const SizedBox.shrink();
    // entriesForSubject returns newest-first per Drift's order-by
    // recorded_at desc. Find the first one from today.
    Entry? todayEntry;
    final todayStart = DateTime.now().copyWith(
      hour: 0,
      minute: 0,
      second: 0,
      millisecond: 0,
      microsecond: 0,
    );
    for (final e in entries) {
      final ts = DateTime.tryParse(e.recordedAt);
      if (ts == null) continue;
      if (ts.isAfter(todayStart)) {
        todayEntry = e;
        break;
      }
    }
    if (todayEntry == null) return const SizedBox.shrink();
    final attachmentsAsync = ref.watch(
      familyAttachmentsForEntityProvider(
        (kind: 'entry', id: todayEntry.id, subjectId: subjectId),
      ),
    );
    final urls = attachmentsAsync.value?.urls ?? const <String>[];
    if (urls.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ts = DateTime.tryParse(todayEntry.recordedAt);
    final timeLabel = ts == null
        ? 'today'
        : DateFormat.jm().format(ts.toLocal());
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PersonPhotoNetwork(
                urlOrPath: urls.first,
                placeholderBuilder: (_) => Container(
                  color: scheme.surfaceContainerHigh,
                ),
              ),
            ),
            // Caption strip — translucent bar with the time + first
            // line of the observation body so the photo isn't
            // context-less.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$timeLabel · ${(todayEntry.body ?? '').split('\n').first}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white, // raw-canvas: label over the photo
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (urls.length > 1)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${urls.length - 1}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white, // raw-canvas: badge over the photo
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Recent reports" surface on Family Today — the progress-report PDFs
/// the staff have sent the guardian. Closes the last Tier-B item from
/// the 2026-05-23 persona-audit (Lauren / Devon / Helen / Marcus).
///
/// Renders nothing when the inbox is empty, so the card never adds
/// chrome on a quiet day. Shows at most three rows; "View all"
/// affordance is deferred — once we have more than a handful of rows
/// per family the per-child detail screen will absorb the overflow.
///
/// Tap → mint a 10-minute signed Storage URL via
/// [ExportActions.downloadUrl] and hand it to `url_launcher`. The OS
/// picks a PDF viewer (Drive, browser, third-party reader); we don't
/// host an in-app PDF viewer because Lauren likely already trusts a
/// system viewer for the receipts she gets in email.
class _ReceivedReportsCard extends ConsumerWidget {
  const _ReceivedReportsCard({required this.subjectsById});

  /// Map of `subject.id → Subject` so each report row can render the
  /// child's first name without an extra DB lookup per row. Family
  /// Today already has the children list loaded.
  final Map<String, Subject> subjectsById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportsAsync = ref.watch(myReceivedExportsProvider);
    final exports = exportsAsync.value ?? const <ReceivedExport>[];
    if (exports.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visible = exports.length > 3 ? exports.sublist(0, 3) : exports;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    exports.length == 1
                        ? 'Recent report'
                        : 'Recent reports',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (exports.length > visible.length)
                    Text(
                      '+${exports.length - visible.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            for (final e in visible)
              _ReceivedReportRow(
                export: e,
                subjectName: e.subjectId == null
                    ? null
                    : subjectsById[e.subjectId]?.firstName,
              ),
          ],
        ),
      ),
    );
  }
}

class _ReceivedReportRow extends ConsumerStatefulWidget {
  const _ReceivedReportRow({required this.export, required this.subjectName});

  final ReceivedExport export;
  final String? subjectName;

  @override
  ConsumerState<_ReceivedReportRow> createState() =>
      _ReceivedReportRowState();
}

class _ReceivedReportRowState extends ConsumerState<_ReceivedReportRow> {
  bool _opening = false;

  /// Mint a 10-minute signed Storage URL from the export's path and
  /// hand it to the OS. 10 minutes is the existing convention — enough
  /// to view, not enough to ship the URL into an email and have it
  /// still work in an hour. (Sharing is what the staff `send` action
  /// is for.) The path comes from the direct PostgREST query in
  /// `myReceivedExportsProvider`; we don't go through the Drift mirror
  /// `ExportActions.downloadUrl` because the local Drift `exports`
  /// table is empty for guardians (by_space sync stream limitation).
  ///
  /// Also stamps the guardian's `export_recipients.read_at` (Devon
  /// persona, Wave 42) — fire-and-forget so a slow round-trip doesn't
  /// block the launchUrl. The card refreshes via provider invalidation
  /// once the round-trip lands, so the "Seen" badge appears on next
  /// rebuild. Errors on the mark-read are swallowed (the user already
  /// has the PDF open by then; a missed timestamp isn't worth a
  /// snackbar).
  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final path = widget.export.storagePath;
      if (path == null) {
        if (!mounted) return;
        messenger?.showSnackBar(
          const SnackBar(
            content: Text("This report isn't ready to view yet."),
          ),
        );
        return;
      }
      final url = await mintExportSignedUrl(path);
      if (!mounted) return;
      final uri = Uri.parse(url);
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (!ok) {
        messenger?.showSnackBar(
          const SnackBar(
            content:
                Text("Couldn't open the report. Try again or check email."),
          ),
        );
        return;
      }
      // PDF opened successfully — stamp read_at + refresh the card so
      // the "Seen" badge shows on next rebuild. Done in the background
      // because the user already has the document open.
      final viewer = ref.read(viewerProvider);
      if (viewer is GuardianViewer && widget.export.myReadAt == null) {
        unawaited(
          markReceivedExportRead(
            exportId: widget.export.id,
            guardianId: viewer.guardian.id,
          ).then(
            (_) {
              if (mounted) ref.invalidate(myReceivedExportsProvider);
            },
            onError: (Object _, _) {
              // Swallow — user has the PDF; missed stamp isn't fatal.
            },
          ),
        );
      }
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'family'),
      );
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not load the report.')),
      );
    } finally {
      // The `if (!mounted) return` early-exits inside the try block
      // each guard `setState` with their own mounted check; this
      // finally still runs but is guarded too, so the unmounted path
      // is safe end-to-end.
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sentRaw = widget.export.sentAt;
    final sent = sentRaw == null
        ? null
        : DateTime.tryParse(sentRaw)?.toLocal();
    final label = widget.subjectName == null
        ? 'Progress report'
        : '${widget.subjectName} · Progress report';
    final subtitle = sent == null
        ? 'Sent recently'
        : 'Sent ${DateFormat.yMMMd().add_jm().format(sent)}';
    // Devon persona (Wave 42): once the guardian taps to open the
    // PDF, their `export_recipients.read_at` is stamped. The check-
    // mark badge on subsequent rebuilds tells the parent which
    // reports they've already worked through — useful when 3 PDFs
    // arrive on a Monday morning.
    final hasBeenRead = widget.export.myReadAt != null;
    return InkWell(
      onTap: _opening ? null : _open,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Row(
          children: [
            Icon(
              hasBeenRead
                  ? Icons.task_alt
                  : Icons.description_outlined,
              size: 20,
              color: hasBeenRead ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hasBeenRead
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasBeenRead ? '$subtitle · Seen' : subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight:
                          hasBeenRead ? FontWeight.w600 : null,
                    ),
                  ),
                ],
              ),
            ),
            if (_opening)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.open_in_new,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

/// Today's recap, on the family lens — the room's shared day + this child's own
/// moments, from the per-child recap entry staff send (already scrubbed of other
/// children's names; see recap_model.dart). Renders nothing until today's recap
/// is sent, so the child card stays tight on a quiet morning.
class _TodaysRecapPeek extends ConsumerWidget {
  const _TodaysRecapPeek({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries =
        ref
            .watch(
              familyEntriesForSubjectProvider((
                subjectId: subjectId,
                kind: EntryKind.recap,
              )),
            )
            .value ??
        const <Entry>[];
    if (entries.isEmpty) return const SizedBox.shrink();
    final today = todayKey();
    RecapView? view;
    for (final e in entries) {
      try {
        final parsed = RecapView.fromJson(
          jsonDecode(e.details) as Map<String, dynamic>,
        );
        if (parsed.date == today) {
          view = parsed;
          break;
        }
      } on Object {
        // A malformed recap row just doesn't render.
      }
    }
    final v = view;
    if (v == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: _RecapPeekCard(view: v),
    );
  }
}

/// The recap card itself — a left-edge tinted panel: the room's day, the
/// optional moment, then this child's own moments (their answer + hero).
class _RecapPeekCard extends StatelessWidget {
  const _RecapPeekCard({required this.view});

  final RecapView view;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border(left: BorderSide(color: scheme.primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 16,
                color: scheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'today’s recap',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (view.activities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in view.activities)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(a, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ],
          if (view.moment != null && view.moment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(view.moment!, style: theme.textTheme.bodyMedium),
          ],
          if (view.question != null && view.question!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              view.question!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (view.answer != null && view.answer!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '“${view.answer}”',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          if (view.heroName != null && view.heroName!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.shield_moon_outlined,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${view.childName}’s hero today: ${view.heroName}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
