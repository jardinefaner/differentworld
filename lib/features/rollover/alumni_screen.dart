import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/features/rollover/rollover_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Past children (docs/ROLLOVER.md).
///
/// The proof that a rollover kept its promise. Everyone here left the active
/// roster and lost nothing: their photos, notes, observations and book all
/// still open. A child who comes back after a year away is one tap from
/// being enrolled again.
class AlumniScreen extends ConsumerWidget {
  const AlumniScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = ref.watch(verticalLabelsProvider);
    final alumniAsync = ref.watch(alumniProvider);

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: alumniAsync.when(
              loading: () => const LoadingSlot(),
              error: (_, _) => ErrorState(
                title:
                    'Could not load past '
                    '${labels.subjectPlural.toLowerCase()}',
                onRetry: () => ref.invalidate(alumniProvider),
              ),
              data: (alumni) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: [
                  ContentHeader(
                    title: 'Past ${labels.subjectPlural.toLowerCase()}',
                    subtitle: alumni.isEmpty
                        ? 'Nobody has moved on yet.'
                        : '${alumni.length} ${alumni.length == 1 ? 'child' : 'children'} · every book still opens',
                  ),
                  if (alumni.isEmpty)
                    EmptyState(
                      icon: Icons.history_outlined,
                      title: 'No past ${labels.subjectPlural.toLowerCase()}',
                      message:
                          'When you start a new year, anyone who moves on '
                          'lands here — with everything they made.',
                    )
                  else ...[
                    for (final s in alumni)
                      _AlumniRow(subject: s, labels: labels),
                    const SizedBox(height: 12),
                    Text(
                      'Past ${labels.subjectPlural.toLowerCase()} stay out of '
                      'attendance, pickers and today’s rosters — and keep '
                      'everything else.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlumniRow extends ConsumerWidget {
  const _AlumniRow({required this.subject, required this.labels});

  final Subject subject;
  final VerticalLabels labels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = '${subject.firstName} ${subject.lastName}'.trim();
    final history = ref.watch(enrollmentHistoryProvider(subject.id)).value;
    final rooms = history == null || history.isEmpty
        ? 'Was with you before the year rollover'
        : '${history.length} ${history.length == 1 ? 'year' : 'years'} with you';

    return FeatureCard(
      leading: PersonAvatar(
        name: name,
        photoUrl: subject.photoUrl,
        radius: 20,
      ),
      title: name,
      subtitle: rooms,
      trailing: const Icon(Icons.menu_book_outlined, size: 20),
      onTap: () => unawaited(context.push('/book/${subject.id}')),
    );
  }
}
