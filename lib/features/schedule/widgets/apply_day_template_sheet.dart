import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/day_template.dart';
import 'package:differentworld/features/schedule/day_template_providers.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Open the "apply a day template to a date" sheet — pick the day + the rooms,
/// then materialize the template's blocks into real `schedule_blocks`. Shared
/// so it's reachable from BOTH the template editor AND the templates list (the
/// connection that makes a built template actually usable, docs not just a
/// drawing).
Future<void> showApplyDayTemplateSheet(
  BuildContext context, {
  required DayTemplate template,
  required String spaceId,
}) {
  if (template.blocks.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add a block to the template first.')),
    );
    return Future<void>.value();
  }
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ApplyDayTemplateSheet(template: template, spaceId: spaceId),
  );
}

/// The apply sheet body (date + room picker → applyToDate).
class ApplyDayTemplateSheet extends ConsumerStatefulWidget {
  const ApplyDayTemplateSheet({
    required this.template,
    required this.spaceId,
    super.key,
  });

  final DayTemplate template;
  final String spaceId;

  @override
  ConsumerState<ApplyDayTemplateSheet> createState() =>
      _ApplyDayTemplateSheetState();
}

class _ApplyDayTemplateSheetState extends ConsumerState<ApplyDayTemplateSheet> {
  DateTime _date = DateTime.now();
  final Set<String> _groupIds = {};
  bool _initialized = false;
  bool _submitting = false;

  String _dateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    // Default: every room selected (the shared-shape default).
    if (!_initialized && groups.isNotEmpty) {
      _groupIds.addAll(groups.map((g) => g.id));
      _initialized = true;
    }

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Apply “${widget.template.name}”',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Generates ${widget.template.blocks.length} blocks. Existing '
                'blocks on that day are kept.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(_date.year - 1),
                    lastDate: DateTime(_date.year + 2),
                  );
                  if (picked != null && mounted) {
                    setState(() => _date = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_dateLabel(_date)),
              ),
              const SizedBox(height: 16),
              Text('Rooms', style: theme.textTheme.labelLarge),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No rooms yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final g in groups)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(g.name),
                  value: _groupIds.contains(g.id),
                  onChanged: (v) => setState(() {
                    if (v ?? false) {
                      _groupIds.add(g.id);
                    } else {
                      _groupIds.remove(g.id);
                    }
                  }),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _groupIds.isEmpty || _submitting
                    ? null
                    : () => _submit(context),
                icon: const Icon(Icons.event_available),
                label: Text(_submitting ? 'Applying…' : 'Apply to this day'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    setState(() => _submitting = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final n = await ref.read(dayTemplateActionsProvider).applyToDate(
          spaceId: widget.spaceId,
          templateId: widget.template.id,
          date: _date,
          groupIds: _groupIds.toList(),
        );
    if (!mounted) return;
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          n == 0
              ? 'Nothing to apply.'
              : 'Added $n ${n == 1 ? "block" : "blocks"} to '
                  '${_dateLabel(_date)}.',
        ),
      ),
    );
  }
}
