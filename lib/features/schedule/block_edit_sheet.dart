import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/activity_edit_screen.dart';
import 'package:differentworld/features/schedule/locations_list_screen.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sentinel value used as the dropdown value for "+ New …" rows. A
/// real uuid will never collide. The dropdowns intercept this and
/// push the relevant edit screen inline, then auto-select the new
/// entity's id when the user returns.
const String _kSentinelNew = '__new__';

/// Bottom sheet to create or edit a single schedule block. Holds the
/// canonical authoring controls — kind, time range, activity, lead,
/// location override, notes. Saving routes through
/// [ScheduleActions.create] / [ScheduleActions.update_].
class BlockEditSheet extends ConsumerStatefulWidget {
  const BlockEditSheet({
    required this.groupId,
    required this.defaultStart,
    this.existing,
    super.key,
  });

  final String groupId;
  final DateTime defaultStart;
  final ScheduleBlock? existing;

  bool get isEdit => existing != null;

  @override
  ConsumerState<BlockEditSheet> createState() => _BlockEditSheetState();
}

class _BlockEditSheetState extends ConsumerState<BlockEditSheet> {
  late String _kind;
  late DateTime _startAt;
  late DateTime _endAt;
  String? _activityId;
  String? _leadMemberId;
  String? _locationOverrideId;
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) {
      _kind = 'on_site';
      _startAt = widget.defaultStart;
      _endAt = widget.defaultStart.add(const Duration(minutes: 60));
    } else {
      _kind = e.kind;
      _startAt = DateTime.parse(e.startAt).toLocal();
      _endAt = DateTime.parse(e.endAt).toLocal();
      _activityId = e.activityId;
      _leadMemberId = e.leadMemberId;
      _locationOverrideId = e.locationOverrideId;
      _notes.text = e.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// When the user picks a new activity, copy that activity's defaults
  /// into the unset fields (location, end_at via default duration) —
  /// but never stomp values the user explicitly set.
  void _applyActivityDefaults(String? activityId, List<Activity> all) {
    if (activityId == null) return;
    final a = all.where((x) => x.id == activityId).firstOrNull;
    if (a == null) return;
    setState(() {
      _activityId = activityId;
      if (a.defaultLocationId != null && _locationOverrideId == null) {
        _locationOverrideId = a.defaultLocationId;
      }
      final dur = a.defaultDurationMinutes;
      if (dur != null) {
        // Only auto-stretch the end time if the user hasn't customized
        // it beyond the seed default we set on init.
        final wasDefault = _endAt.difference(_startAt).inMinutes == 60 ||
            (widget.existing != null &&
                widget.existing!.activityId == null);
        if (wasDefault) {
          _endAt = _startAt.add(Duration(minutes: dur));
        }
      }
    });
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (picked == null) return;
    setState(() {
      final newStart = DateTime(
        _startAt.year,
        _startAt.month,
        _startAt.day,
        picked.hour,
        picked.minute,
      );
      final delta = _endAt.difference(_startAt);
      _startAt = newStart;
      // Slide the end with the start so the duration is preserved.
      _endAt = newStart.add(delta);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endAt),
    );
    if (picked == null) return;
    setState(() {
      _endAt = DateTime(
        _endAt.year,
        _endAt.month,
        _endAt.day,
        picked.hour,
        picked.minute,
      );
      // Guard: if the user picks an end before the start, clamp to
      // start + 15 min.
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 15));
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final actions = ref.read(scheduleActionsProvider);

    final ok = await runReported(
      library: 'schedule',
      messenger: messenger,
      onError: 'Could not save the block.',
      action: () async {
        final notes = _notes.text.trim();
        if (widget.existing == null) {
          await actions.create(
            groupId: widget.groupId,
            startAt: _startAt,
            endAt: _endAt,
            activityId: _kind == 'on_site' || _kind == 'field_trip'
                ? _activityId
                : null,
            leadMemberId: _leadMemberId,
            locationOverrideId: _locationOverrideId,
            kind: _kind,
            notes: notes.isEmpty ? null : notes,
          );
        } else {
          await actions.update_(
            id: widget.existing!.id,
            startAt: _startAt,
            endAt: _endAt,
            activityId: _activityId,
            leadMemberId: _leadMemberId,
            locationOverrideId: _locationOverrideId,
            kind: _kind,
            notes: notes.isEmpty ? null : notes,
          );
        }
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop();
  }

  Future<void> _delete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this block?'),
        content: const Text("It will be removed from this cohort's day."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final navigator = Navigator.of(context);
    await ref.read(scheduleActionsProvider).delete_(id);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final insets = MediaQuery.of(context).viewInsets;
    final activities = ref.watch(allActivitiesProvider).value ??
        const <Activity>[];
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    final members = ref.watch(membersInSpaceProvider).value ?? const <Member>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + insets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                widget.isEdit ? 'Edit block' : 'New block',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              if (widget.isEdit)
                IconButton(
                  tooltip: 'Delete',
                  icon: Icon(Icons.delete_outline, color: scheme.error),
                  onPressed: _saving ? null : _delete,
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Kind segmented control: on_site / field_trip / break /
          // closed. Drives which fields below are relevant.
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'on_site',
                label: Text('Activity'),
              ),
              ButtonSegment(
                value: 'field_trip',
                label: Text('Trip'),
                icon: Icon(Icons.directions_bus_outlined),
              ),
              ButtonSegment(
                value: 'break',
                label: Text('Break'),
              ),
              ButtonSegment(
                value: 'closed',
                label: Text('Closed'),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) setState(() => _kind = s.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          // Time range — two tappable pills.
          Row(
            children: [
              Expanded(
                child: _TimePill(
                  label: 'Start',
                  value: TimeOfDay.fromDateTime(_startAt),
                  onTap: _pickStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TimePill(
                  label: 'End',
                  value: TimeOfDay.fromDateTime(_endAt),
                  onTap: _pickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${_endAt.difference(_startAt).inMinutes} min',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (_kind == 'on_site' || _kind == 'field_trip') ...[
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _activityId,
              decoration: const InputDecoration(
                labelText: 'Activity',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  child: Text('— pick an activity —'),
                ),
                for (final a in activities
                    .where((x) => x.archivedAt == null || x.id == _activityId))
                  DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text(
                      a.archivedAt == null ? a.name : '${a.name} (archived)',
                    ),
                  ),
                // "+ New activity" sentinel — picking it pushes the
                // activity edit screen inline, then auto-selects the
                // returned id. The user never has to leave the block
                // sheet to add a new activity to the catalog.
                DropdownMenuItem<String?>(
                  value: _kSentinelNew,
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'New activity…',
                        style: TextStyle(color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (v) async {
                if (v == _kSentinelNew) {
                  // Push the activity edit screen, await the new id,
                  // then re-apply defaults to slide end-time etc.
                  final newId = await Navigator.of(context).push<String?>(
                    MaterialPageRoute(
                      builder: (_) => const ActivityEditScreen(),
                    ),
                  );
                  if (!mounted || newId == null) return;
                  // The activities stream may not have emitted the new
                  // row yet — give it one frame.
                  await Future<void>.delayed(
                    const Duration(milliseconds: 50),
                  );
                  if (!mounted) return;
                  final fresh = ref.read(allActivitiesProvider).value ??
                      const <Activity>[];
                  _applyActivityDefaults(newId, fresh);
                  return;
                }
                _applyActivityDefaults(v, activities);
              },
            ),
          ],
          if (_kind != 'closed') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _leadMemberId,
              decoration: const InputDecoration(
                labelText: 'Lead',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  child: Text('— unassigned —'),
                ),
                for (final m in members)
                  DropdownMenuItem<String?>(
                    value: m.id,
                    child: Text(m.displayName),
                  ),
              ],
              onChanged: (v) => setState(() => _leadMemberId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _locationOverrideId,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  child: Text('— activity default —'),
                ),
                for (final l in locations)
                  DropdownMenuItem<String?>(
                    value: l.id,
                    child: Text(l.name),
                  ),
                // "+ New location" sentinel — same pattern as the
                // activity dropdown above.
                DropdownMenuItem<String?>(
                  value: _kSentinelNew,
                  child: Row(
                    children: [
                      Icon(Icons.add, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'New location…',
                        style: TextStyle(color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
              onChanged: (v) async {
                if (v == _kSentinelNew) {
                  final newId = await openLocationEditSheet(context);
                  if (!mounted || newId == null) return;
                  setState(() => _locationOverrideId = newId);
                  return;
                }
                setState(() => _locationOverrideId = v);
              },
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: _kind == 'break'
                  ? 'Label'
                  : _kind == 'closed'
                      ? 'Reason (optional)'
                      : 'Notes (optional)',
              hintText: _kind == 'break'
                  ? 'Snack · Lunch · Rest'
                  : _kind == 'closed'
                      ? 'Holiday · weather · maintenance'
                      : 'Anything specific staff or parents should see',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.isEdit ? 'Save changes' : 'Add block'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final TimeOfDay value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value.format(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
