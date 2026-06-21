import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/entities/linkified_text.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/hover_tap.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One beat in a Story timeline — emoji on the spine, a tinted card with
/// the headline, time, optional body + photos. When [subject] is given
/// (the room Story, where moments span children) it leads with that
/// child's avatar + name.
class MomentTile extends ConsumerWidget {
  const MomentTile({required this.moment, this.subject, super.key});

  final Moment moment;
  final Subject? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final when = moment.when;
    final photos = moment.showsPhotos
        ? (ref
                .watch(attachmentsForEntityProvider(
                  (kind: 'entry', id: moment.id),
                ))
                .value
                ?.urls ??
            const <String>[])
        : const <String>[];
    final name = subject == null
        ? null
        : '${subject!.firstName} ${subject!.lastName}'.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(moment.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (subject != null) ...[
                        PersonAvatar(
                          name: name!,
                          photoUrl: subject!.photoUrl,
                          radius: 11,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: EntityLink(
                            entity: EntityRef(
                              kind: EntityKind.subject,
                              id: subject!.id,
                              label: subject!.firstName,
                            ),
                            padded: false,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (when != null)
                        Text(
                          timeOfDay(when),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    moment.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (moment.body != null) ...[
                    const SizedBox(height: 4),
                    LinkifiedText(moment.body!),
                  ],
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PhotoStrip(urls: photos),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => HoverTap(
          onTap: () => PhotoViewer.open(context, urls: urls, initialIndex: i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 96,
              child: PersonPhotoNetwork(
                urlOrPath: urls[i],
                errorBuilder: (_) => Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared day-bucket label for Story timelines (Today / Yesterday /
/// weekday / date).
String storyDayLabel(DateTime when) {
  final now = DateTime.now();
  final d = DateTime(when.year, when.month, when.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return _weekday(when);
  return '${_month(when)} ${when.day}, ${when.year}';
}

String _weekday(DateTime d) => const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][d.weekday - 1];

String _month(DateTime d) => const [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ][d.month - 1];
