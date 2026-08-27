import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/class_memory/class_memory.dart';
import 'package:differentworld/features/class_memory/class_memory_providers.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/inline_add.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What this room remembers (docs/VISION.md — the Keep function).
///
/// Written in the room's own voice — "questions WE haven't answered" — because
/// it is the class's memory, not a staff record about them. That is not
/// decoration: the same list titled "unresolved queries" is a task backlog,
/// and a backlog is a thing you feel behind on rather than a thing you are
/// glad to have.
///
/// Every heading renders even when empty. A heading is a prompt as much as a
/// label, and a room that has never recorded a question is exactly the room
/// that benefits from seeing that it could.
class ClassMemoryScreen extends ConsumerWidget {
  const ClassMemoryScreen({required this.groupId, super.key});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = (ref.watch(groupsProvider).value ?? const <Group>[])
        .where((g) => g.id == groupId)
        .firstOrNull;
    final bySort = ref.watch(classMemoriesBySortProvider(groupId));
    final total = bySort.values.fold<int>(0, (a, b) => a + b.length);

    return EdgeScaffold(
      backFallbackRoute: '/groups/$groupId',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                ContentHeader(
                  title: group == null
                      ? 'What this room remembers'
                      : 'What ${group.name} remembers',
                  subtitle: total == 0
                      ? null
                      : total == 1
                      ? '1 thing kept'
                      : '$total things kept',
                ),
                if (total == 0)
                  const EmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: 'Nothing kept yet',
                    message:
                        'When someone asks a question nobody can answer, or '
                        'the room works something out together, keep it here. '
                        'It can come back later.',
                  ),
                for (final sort in ClassMemorySort.values)
                  _SortBand(
                    key: ValueKey('sort-${sort.id}'),
                    groupId: groupId,
                    sort: sort,
                    memories: bySort[sort] ?? const [],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SortBand extends ConsumerWidget {
  const _SortBand({
    required this.groupId,
    required this.sort,
    required this.memories,
    super.key,
  });

  final String groupId;
  final ClassMemorySort sort;
  final List<ClassMemory> memories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: theme.colorScheme.outlineVariant, width: 2),
          ),
        ),
        padding: const EdgeInsets.only(left: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sort.heading, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final m in memories)
              _MemoryRow(
                key: ValueKey('memory-${m.id}'),
                memory: m,
                sort: sort,
              ),
            InlineAdd(
              hint: _hintFor(sort),
              width: 260,
              onSubmit: (text) => ref
                  .read(classMemoryActionsProvider)
                  .keep(groupId: groupId, sort: sort, text: text),
            ),
          ],
        ),
      ),
    );
  }

  /// The hint names what ONE entry is, in the words a staffer would use in
  /// the moment — not the category name repeated back at them.
  String _hintFor(ClassMemorySort sort) => switch (sort) {
    ClassMemorySort.question => 'Something we wondered',
    ClassMemorySort.discovery => 'Something we worked out',
    ClassMemorySort.word => 'A word we started using',
  };
}

class _MemoryRow extends StatelessWidget {
  const _MemoryRow({required this.memory, required this.sort, super.key});

  final ClassMemory memory;
  final ClassMemorySort sort;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Hoisted so the null check is a real promotion rather than a `!` — the
    // row renders fine without a timestamp, which is the point of it being
    // nullable at all.
    final at = memory.recordedAt;
    final ctx = memory.context;
    final meta = [
      if (at != null) relativeTimeAgo(at),
      if (ctx != null) 'during $ctx',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The serif is doing real work here: these are somebody's actual
          // words, and setting them in the body font makes them read as a
          // log entry rather than a thing that was said out loud.
          Text(
            sort == ClassMemorySort.word ? memory.text : '“${memory.text}”',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontFamily: theme.textTheme.headlineSmall?.fontFamily,
            ),
          ),
          if (meta.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                meta,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
