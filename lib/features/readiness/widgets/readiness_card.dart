import 'dart:async';

import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/features/readiness/readiness.dart';
import 'package:differentworld/features/readiness/readiness_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What today needs, on the surface you already open (docs/READINESS.md).
///
/// Renders NOTHING when there is nothing to do — the card exists to be got
/// rid of, not to be lived with. Rows name people rather than counting them,
/// and each one goes somewhere you can act.
class ReadinessCard extends ConsumerWidget {
  const ReadinessCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(readinessProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            items.length == 1
                ? 'Today needs one thing'
                : 'Today needs ${items.length} things',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 2),
          Text(
            'While everyone is still here.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            _Row(item: item, subjectWord: labels.subject.toLowerCase()),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.subjectWord});

  final ReadinessItem item;
  final String subjectWord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgent =
        item.kind == ReadinessKind.missingGuardian ||
        item.kind == ReadinessKind.missingAllergyAnswer;

    return InkWell(
      onTap: () => _go(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _icon,
              size: 20,
              color: urgent
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_title, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 1),
                  Text(
                    _detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (item.kind) {
    ReadinessKind.missingGuardian => Icons.phone_outlined,
    ReadinessKind.missingAllergyAnswer => Icons.warning_amber_outlined,
    ReadinessKind.missingConsent => Icons.verified_user_outlined,
    ReadinessKind.missingPhoto => Icons.photo_camera_outlined,
    ReadinessKind.neverArranged => Icons.groups_outlined,
  };

  String get _title => switch (item.kind) {
    ReadinessKind.missingGuardian =>
      item.count == 1
          ? 'One $subjectWord has nobody to call'
          : '${item.count} have nobody to call',
    ReadinessKind.missingAllergyAnswer =>
      item.count == 1
          ? 'One allergy question unanswered'
          : '${item.count} allergy questions unanswered',
    ReadinessKind.missingConsent =>
      item.count == 1
          ? 'One family hasn’t answered about photos'
          : '${item.count} families haven’t answered about photos',
    ReadinessKind.missingPhoto =>
      item.count == 1
          ? 'One $subjectWord has no photo'
          : '${item.count} have no photo',
    ReadinessKind.neverArranged =>
      '${item.groupName ?? 'A room'} has never been arranged',
  };

  String get _detail => switch (item.kind) {
    ReadinessKind.missingGuardian => _names('no guardian on file'),
    ReadinessKind.missingAllergyAnswer =>
      'Blank isn’t the same as none — ${_namesRaw()}',
    ReadinessKind.missingConsent => _names('ask before the camera comes out'),
    ReadinessKind.missingPhoto => _names('every family is here right now'),
    ReadinessKind.neverArranged =>
      'Mix the strangers — ${item.count} here today',
  };

  String _namesRaw() {
    if (item.names.isEmpty) return '';
    final more = item.count - item.names.length;
    final list = item.names.join(', ');
    return more > 0 ? '$list and $more more' : list;
  }

  String _names(String fallback) {
    final n = _namesRaw();
    return n.isEmpty ? fallback : n;
  }

  void _go(BuildContext context) {
    switch (item.kind) {
      case ReadinessKind.neverArranged:
        unawaited(context.push('/groups/${item.groupId}'));
      case ReadinessKind.missingGuardian:
      case ReadinessKind.missingAllergyAnswer:
      case ReadinessKind.missingConsent:
      case ReadinessKind.missingPhoto:
        // Every one of these is fixed on a child's record, and the roster is
        // where you pick which child — one hop, not a deep link per item.
        unawaited(context.push('/subjects'));
    }
  }
}
