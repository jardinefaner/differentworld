import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/story/moment.dart';
import 'package:differentworld/features/story/widgets/moment_tile.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:flutter/material.dart';

/// The shared Story timeline — a [title] header, then moments newest-first
/// with a day header (Today / Yesterday / weekday / date) when the day
/// changes. Pass [subjectsById] (the room Story) to show which child each
/// moment belongs to; leave empty for a single child's Story.
class StoryTimeline extends StatelessWidget {
  const StoryTimeline({
    required this.title,
    required this.moments,
    this.subjectsById = const {},
    super.key,
  });

  final String title;
  final List<Moment> moments;
  final Map<String, Subject> subjectsById;

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[];
    String? lastKey;
    for (final m in moments) {
      final when = m.when;
      final key = when == null ? '—' : dateKey(when);
      if (key != lastKey) {
        rows.add(_Row.header(when == null ? 'Earlier' : storyDayLabel(when)));
        lastKey = key;
      }
      rows.add(_Row.moment(m));
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.splitMaxWidth),
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          itemCount: rows.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: ContentHeader(
                  title: title,
                  subtitle:
                      moments.length == 1 ? '1 moment' : '${moments.length} moments',
                ),
              );
            }
            final row = rows[i - 1];
            if (row.header != null) return _DayHeader(label: row.header!);
            final m = row.moment!;
            return MomentTile(
              moment: m,
              subject: subjectsById[m.entry.subjectId],
            );
          },
        ),
      ),
    );
  }
}

class _Row {
  const _Row.header(this.header) : moment = null;
  const _Row.moment(this.moment) : header = null;
  final String? header;
  final Moment? moment;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
