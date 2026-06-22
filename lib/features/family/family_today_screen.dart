import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/attendance/attendance_status.dart';
import 'package:differentworld/features/exports/exports_providers.dart';
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/family/widgets/received_reports_card.dart';
import 'package:differentworld/features/family/widgets/todays_recap_peek.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/schedule/widgets/now_next_strip.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/settings/widgets/text_size_tile.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
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
          .watch(
            familyAttendanceForSubjectProvider(
              (subjectId: c.id, dateIso: _todayIso),
            ),
          )
          .value;
      if (myRecord == null) continue;
      final s = AttendanceStatus.fromDb(myRecord.status);
      if (s == AttendanceStatus.late || s == AttendanceStatus.absent) {
        flagged.add(c);
      }
    }

    final header = ContentHeader(
      title: space?.name ?? 'Today',
      subtitle: _subtitle(guardianName: guardianName, flagged: flagged),
      subtitleColor: flagged.isEmpty
          ? null
          : Theme.of(context).colorScheme.error,
    );

    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). The family feed is text/photo-heavy (each child
    // card carries a photo-of-the-moment hero + recap), so the bento variant
    // keeps every tile FULL-WIDTH on phone (the calm card treatment, NOT a
    // forced 2-up — that would truncate the narrative + photos) and only goes
    // 2-up on tablet/desktop where there's room. Same providers, same per-
    // child privacy scoping; only the packing changes.
    final bento = bentoEnabled(ref, perScreen: null);
    if (bento) {
      return _bentoBody(context, ref, header: header, flagged: flagged);
    }

    return ResponsivePage(
      children: [
        header,
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
        ReceivedReportsCard(
          subjectsById: {for (final c in children) c.id: c},
        ),
        for (final child in children) ...[
          _ChildCard(child: child),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  /// The bento variant — the SAME summary / reports / per-child cards, re-laid
  /// as bento tiles over the same providers. Everything is full-width on phone
  /// (the cards are narrative + photo-heavy, so a 2-up would truncate); the
  /// per-child cards go 2-up on tablet/desktop where the width is there.
  ///
  /// The reports tile is emitted ONLY when the guardian actually has reports —
  /// a bento cell reserves its `minHeight`, so wrapping the self-hiding
  /// [ReceivedReportsCard] unconditionally would leave a blank box on a quiet
  /// day. We watch the same provider the card reads to decide.
  Widget _bentoBody(
    BuildContext context,
    WidgetRef ref, {
    required Widget header,
    required List<Subject> flagged,
  }) {
    final hasReports =
        (ref.watch(myReceivedExportsProvider).value ?? const []).isNotEmpty;
    final tiles = <BentoTile>[
      BentoTile(
        id: 'summary',
        span: const BentoSpan.wide(),
        child: _SummarySentence(children: children, flagged: flagged),
      ),
      if (hasReports)
        BentoTile(
          id: 'reports',
          span: const BentoSpan.wide(),
          child: ReceivedReportsCard(
            subjectsById: {for (final c in children) c.id: c},
          ),
        ),
      for (final child in children)
        BentoTile(
          // Stable per-child key so a card vanishing (a child unlinked
          // mid-session) can't poison a neighbour's Element in the Wrap.
          id: 'child-${child.id}',
          // Full-width on phone (default 2-of-2) — the card's photo hero +
          // recap need the room. Tablet default 2-of-4 (2-up); desktop
          // 3-of-6 (2-up).
          span: const BentoSpan(desktop: 3),
          child: _ChildCard(child: child),
        ),
    ];

    return ResponsivePage(
      children: [
        header,
        const SizedBox(height: 12),
        BentoGrid(tiles: tiles),
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
        .watch(
          familyAttendanceForSubjectProvider(
            (subjectId: child.id, dateIso: _todayIso),
          ),
        )
        .value;
    final status = myRecord == null
        ? null
        : AttendanceStatus.fromDb(myRecord.status);

    final flagged =
        status == AttendanceStatus.late || status == AttendanceStatus.absent;

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
      TodaysRecapPeek(subjectId: child.id),
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
        status.at != null
            ? 'Picked up at ${timeOfDay(status.at!)}'
            : 'Picked up',
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
      final candidate = DateTime(now.year, now.month, now.day, h, m);
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
    final onContainer = hasFlag ? scheme.onErrorContainer : scheme.onSurface;
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

/// "Photo of the moment" peek inside the child card. Surfaces the most recent
/// photo from TODAY — broadened (seam 3) beyond observations to ALSO include
/// the cohort's block captures, so a parent sees the day's pictures even when
/// staff snapped a quick floor photo instead of filing an observation.
///
/// Renders nothing when there's no photo for this child today.
///
/// Privacy: the photo set is scoped in `familyTodaysMomentPhotoProvider` to
/// THIS child's own tagged photos + the cohort's room moments (subject_id
/// null) — never another child's tagged photo. We show NO caption text on the
/// image: a block photo has no per-child narrative, and rendering an
/// observation body here would risk surfacing another child's name. The time
/// label is the only overlay.
///
/// Lauren persona — opens the app at 11 AM during a coffee break, wants the
/// warmest possible "what's my kid up to" signal in one glance.
class _PhotoOfTheMomentPeek extends ConsumerWidget {
  const _PhotoOfTheMomentPeek({required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(familyTodaysMomentPhotoProvider(subjectId)).value;
    if (photo == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tsRaw = photo.takenAt ?? photo.createdAt;
    final ts = DateTime.tryParse(tsRaw);
    final timeLabel = ts == null
        ? 'today'
        : DateFormat.jm().format(ts.toLocal());
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      // Tap the hero to open it full-screen — it's the most prominent surface
      // on the card, so a dead tap reads as broken. Single photo; the viewer
      // handles the signed-URL mint.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => PhotoViewer.open(context, urls: [photo.url]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: PersonPhotoNetwork(
                  urlOrPath: photo.url,
                  placeholderBuilder: (_) => Container(
                    color: scheme.surfaceContainerHigh,
                  ),
                ),
              ),
              // Caption strip — translucent bar with JUST the time. No body text:
              // block photos have none, and an observation body could name
              // another child (privacy — see class doc).
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
                          timeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors
                                .white, // raw-canvas: label over the photo
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
