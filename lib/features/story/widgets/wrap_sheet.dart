import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/story/story_providers.dart';
import 'package:differentworld/features/story/wrap.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The wrap sheet — a today/this-week roll-up of a Story, with a Copy
/// button to send it home. Self-loading: pass [subjectId] for a child's
/// wrap, or null for the room's.
class WrapSheet extends ConsumerStatefulWidget {
  const WrapSheet({required this.subjectName, this.subjectId, super.key});

  final String subjectName;
  final String? subjectId;

  static Future<void> show(
    BuildContext context, {
    required String subjectName,
    String? subjectId,
  }) {
    return showGlassSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WrapSheet(subjectName: subjectName, subjectId: subjectId),
    );
  }

  @override
  ConsumerState<WrapSheet> createState() => _WrapSheetState();
}

class _WrapSheetState extends ConsumerState<WrapSheet> {
  bool _week = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = widget.subjectId == null
        ? ref.watch(spaceMomentsProvider).value ?? const <Entry>[]
        : ref
                .watch(entriesForSubjectProvider(
                  (subjectId: widget.subjectId!, kind: null),
                ))
                .value ??
            const <Entry>[];

    final now = DateTime.now();
    final cutoff = _week
        ? now.subtract(const Duration(days: 7))
        : DateTime(now.year, now.month, now.day);
    final wrap = buildWrap(
      subjectName: widget.subjectName,
      periodLabel: _week ? 'This week' : 'Today',
      entries: entries,
      cutoff: cutoff,
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GlassDragHandle(bottomMargin: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Today')),
                  ButtonSegment(value: true, label: Text('This week')),
                ],
                selected: {_week},
                onSelectionChanged: (s) => setState(() => _week = s.first),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  wrap.text,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: wrap.isEmpty
                      ? null
                      : () async {
                          final messenger = ScaffoldMessenger.of(context);
                          unawaited(HapticFeedback.selectionClick());
                          await Clipboard.setData(
                            ClipboardData(text: wrap.text),
                          );
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Wrap copied')),
                          );
                        },
                  icon: const Icon(Icons.copy_outlined, size: 18),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
