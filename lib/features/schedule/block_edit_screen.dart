import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/curricula/photo_curriculum.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/activity_edit_screen.dart';
import 'package:differentworld/features/schedule/locations_list_screen.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sentinel used as the dropdown value for "+ New …" rows. A real
/// uuid never collides. Dropdowns intercept this and push the
/// relevant edit screen inline, then auto-select the new id when
/// the user returns.
const String _kSentinelNew = '__new__';

/// Args passed to the create/edit block route via go_router `extra`.
///
/// Wave 165 added `prefillCurriculumSlug` — when present, the screen
/// pre-fills the notes + suggested duration from the matching
/// curriculum session, and stamps the saved block with the slug so
/// the grid renders a "Through My Eyes · S{N}" badge.
typedef BlockEditArgs = ({
  String groupId,
  DateTime defaultStart,
  ScheduleBlock? existing,
  String? prefillCurriculumSlug,
});

/// Create or edit a single schedule block — kind, time range,
/// activity, lead, location override, notes. Saves through
/// `ScheduleActions.create` / `update_`.
///
/// Promoted from `block_edit_sheet.dart` to the
/// `/schedule/block` route in Wave 26. Args passed via go_router
/// `extra` so the user can deep-link into a fresh create flow
/// (with groupId + defaultStart) or an edit flow (with the
/// existing ScheduleBlock).
class BlockEditScreen extends ConsumerStatefulWidget {
  const BlockEditScreen({
    required this.groupId,
    required this.defaultStart,
    this.existing,
    this.prefillCurriculumSlug,
    super.key,
  });

  final String groupId;
  final DateTime defaultStart;
  final ScheduleBlock? existing;

  /// Wave 165: when this screen is reached from a curriculum session
  /// "Schedule this session" CTA, the slug arrives here. We use it on
  /// initState to pre-fill the notes + suggested duration from the
  /// session's data, and to stamp the saved block with the slug so
  /// the schedule grid can render the curriculum badge later.
  final String? prefillCurriculumSlug;

  bool get isEdit => existing != null;

  @override
  ConsumerState<BlockEditScreen> createState() => _BlockEditScreenState();
}

class _BlockEditScreenState extends ConsumerState<BlockEditScreen> {
  late String _kind;
  late DateTime _startAt;
  late DateTime _endAt;
  String? _activityId;
  String? _leadMemberId;
  String? _locationOverrideId;
  final _notes = TextEditingController();
  bool _saving = false;

  /// Wave 166.2: when on, the form spawns N blocks (one per matching
  /// weekday between start date and `_repeatUntil`) instead of one.
  /// Only available on new blocks, never on edit — editing a single
  /// instance of a series doesn't propagate.
  bool _repeatOn = false;

  /// Day-of-week mask. Indexed [0]=Mon … [6]=Sun (matches
  /// DateTime.weekday — 1..7 — minus 1). The starting day is
  /// pre-checked on toggle-on.
  late List<bool> _repeatDays;

  /// Last date to spawn (inclusive). Defaults to "+4 weeks from the
  /// start" when the repeat is first enabled.
  late DateTime _repeatUntil;

  /// The curriculum slug this block carries. For new blocks comes
  /// from [BlockEditScreen.prefillCurriculumSlug]; for edits it
  /// reads from the existing row. Persists unchanged on save — the
  /// edit form doesn't expose a way to un-link or re-link (use
  /// delete + re-create from the curriculum CTA for now).
  String? _curriculumSlug;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _repeatDays = List<bool>.filled(7, false);
    _repeatUntil = widget.defaultStart.add(const Duration(days: 28));
    if (e == null) {
      _kind = 'on_site';
      _startAt = widget.defaultStart;
      _endAt = widget.defaultStart.add(const Duration(minutes: 60));
      _repeatDays[(widget.defaultStart.weekday - 1) % 7] = true;
      _curriculumSlug = widget.prefillCurriculumSlug;
      // Wave 165: prefill from curriculum session metadata when the
      // CTA-originated route arrives with a slug. The notes carry the
      // session title + brief; the end-time gets nudged to a sensible
      // default for the session (most photo sessions run 20-30 min).
      final session = _curriculumSlug == null
          ? null
          : findSessionBySlug(_curriculumSlug!);
      if (session != null) {
        _notes.text =
            '${session.title} (Session ${session.number} · '
            'Through My Eyes)';
        // Photo sessions trend ~30 min total. Keep the start the
        // user picked, bump the end out from the default 60 min.
        _endAt = _startAt.add(const Duration(minutes: 30));
      }
    } else {
      _kind = e.kind;
      _startAt = DateTime.parse(e.startAt).toLocal();
      _endAt = DateTime.parse(e.endAt).toLocal();
      _activityId = e.activityId;
      _leadMemberId = e.leadMemberId;
      _locationOverrideId = e.locationOverrideId;
      _notes.text = e.notes ?? '';
      _curriculumSlug = e.curriculumSessionSlug;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  /// When the user picks an activity, copy that activity's defaults
  /// into unset fields (location, end_at via default duration) —
  /// without stomping values the user explicitly set.
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
      if (!_endAt.isAfter(_startAt)) {
        _endAt = _startAt.add(const Duration(minutes: 15));
      }
    });
  }

  /// Wave 166.2: expand the repeat parameters (start date,
  /// `_repeatUntil`, weekday mask) into the list of dates that the
  /// batch should spawn on. Inclusive of both endpoints when they
  /// match the mask.
  List<DateTime> _expandRepeatDates() {
    final out = <DateTime>[];
    var cursor = DateTime(_startAt.year, _startAt.month, _startAt.day);
    final last =
        DateTime(_repeatUntil.year, _repeatUntil.month, _repeatUntil.day);
    while (!cursor.isAfter(last)) {
      final idx = (cursor.weekday - 1) % 7;
      if (_repeatDays[idx]) out.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }

  Future<void> _pickRepeatUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil,
      firstDate: _startAt,
      lastDate: _startAt.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => _repeatUntil = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final goRouter = GoRouter.of(context);
    final actions = ref.read(scheduleActionsProvider);

    final ok = await runReported(
      library: 'schedule',
      messenger: messenger,
      onError: 'Could not save the block.',
      action: () async {
        final notes = _notes.text.trim();
        if (widget.existing == null) {
          if (_repeatOn) {
            // Wave 166.2 — spawn one block per matching weekday in
            // the range. Skip the start day if it's not in the
            // selected mask (user might have unchecked it).
            final dates = _expandRepeatDates();
            await actions.createBatch(
              groupId: widget.groupId,
              dates: dates,
              startAt: _startAt,
              endAt: _endAt,
              activityId: _kind == BlockKind.onSite ||
                      _kind == BlockKind.fieldTrip
                  ? _activityId
                  : null,
              leadMemberId: _leadMemberId,
              locationOverrideId: _locationOverrideId,
              kind: _kind,
              notes: notes.isEmpty ? null : notes,
              curriculumSessionSlug: _curriculumSlug,
            );
          } else {
            await actions.create(
              groupId: widget.groupId,
              startAt: _startAt,
              endAt: _endAt,
              activityId: _kind == BlockKind.onSite ||
                      _kind == BlockKind.fieldTrip
                  ? _activityId
                  : null,
              leadMemberId: _leadMemberId,
              locationOverrideId: _locationOverrideId,
              kind: _kind,
              notes: notes.isEmpty ? null : notes,
              curriculumSessionSlug: _curriculumSlug,
            );
          }
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
    if (ok && goRouter.canPop()) goRouter.pop();
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
    final goRouter = GoRouter.of(context);
    await ref.read(scheduleActionsProvider).delete_(id);
    if (!mounted) return;
    if (goRouter.canPop()) goRouter.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final locations =
        ref.watch(locationsProvider).value ?? const <Location>[];
    final members =
        ref.watch(membersInSpaceProvider).value ?? const <Member>[];

    return EdgeScaffold(
      backFallbackRoute: '/schedule',
      actions: [
        if (widget.isEdit)
          IconButton(
            tooltip: 'Delete',
            icon: Icon(Icons.delete_outline, color: scheme.error),
            onPressed: _saving ? null : _delete,
          ),
      ],
      body: FormBody(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ContentHeader(
            title: widget.isEdit ? 'Edit block' : 'New block',
          ),
          if (_curriculumSlug != null) _CurriculumLinkCard(slug: _curriculumSlug!),
          if (_curriculumSlug != null) const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'on_site', label: Text('Activity')),
              ButtonSegment(
                value: 'field_trip',
                label: Text('Trip'),
                icon: Icon(Icons.directions_bus_outlined),
              ),
              ButtonSegment(value: 'break', label: Text('Break')),
              ButtonSegment(value: 'closed', label: Text('Closed')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) {
              if (s.isNotEmpty) setState(() => _kind = s.first);
            },
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
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
          if (_kind == BlockKind.onSite || _kind == BlockKind.fieldTrip) ...[
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
                  final newId = await Navigator.of(context).push<String?>(
                    MaterialPageRoute(
                      builder: (_) => const ActivityEditScreen(),
                    ),
                  );
                  if (!mounted || newId == null) return;
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
              labelText: _kind == BlockKind.breakBlock
                  ? 'Label'
                  : _kind == BlockKind.closed
                      ? 'Reason (optional)'
                      : 'Notes (optional)',
              hintText: _kind == BlockKind.breakBlock
                  ? 'Snack · Lunch · Rest'
                  : _kind == BlockKind.closed
                      ? 'Holiday · weather · maintenance'
                      : 'Anything specific staff or parents should see',
              border: const OutlineInputBorder(),
            ),
          ),
          if (!widget.isEdit) ...[
            const SizedBox(height: 16),
            _RepeatSection(
              startAt: _startAt,
              endAt: _endAt,
              repeatOn: _repeatOn,
              repeatDays: _repeatDays,
              repeatUntil: _repeatUntil,
              onToggleRepeat: (v) => setState(() => _repeatOn = v),
              onToggleDay: (i) =>
                  setState(() => _repeatDays[i] = !_repeatDays[i]),
              onPickUntil: _pickRepeatUntil,
              expand: _expandRepeatDates,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(
              widget.isEdit
                  ? 'Save changes'
                  : _repeatOn
                      ? 'Add ${_expandRepeatDates().length} blocks'
                      : 'Add block',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          // Wave 155: skip / restore. Only shown when editing an
          // existing block — adding a brand-new block always starts
          // as planned. The director's "cancel" with a reason lives
          // here too: tap Skip → optional reason → snackbar.
          if (widget.isEdit && widget.existing != null) ...[
            const SizedBox(height: 12),
            _SkipRestoreRow(block: widget.existing!),
          ],
        ],
      ),
    );
  }
}

/// Wave 155: skip / restore action on the block edit sheet. Shows
/// the current status (planned / skipped / cancelled), and a
/// single button to toggle.
class _SkipRestoreRow extends ConsumerWidget {
  const _SkipRestoreRow({required this.block});
  final ScheduleBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSkipped = block.status == BlockStatus.skipped ||
        block.status == BlockStatus.cancelled;
    return OutlinedButton.icon(
      onPressed: () async {
        if (isSkipped) {
          await ref.read(scheduleActionsProvider).setBlockStatus(
                id: block.id,
                status: BlockStatus.planned,
              );
          if (context.mounted) Navigator.of(context).maybePop();
          return;
        }
        // Optional reason prompt — kid-mode friendly default.
        final reason = await showDialog<String>(
          context: context,
          builder: (ctx) {
            final ctrl = TextEditingController();
            return AlertDialog(
              title: const Text('Skip this block'),
              content: TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Rain · low attendance · guest cancelled',
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text.trim()),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
                  child: const Text('Skip'),
                ),
              ],
            );
          },
        );
        if (reason == null) return;
        await ref.read(scheduleActionsProvider).setBlockStatus(
              id: block.id,
              status: BlockStatus.skipped,
              reason: reason.isEmpty ? null : reason,
            );
        if (context.mounted) Navigator.of(context).maybePop();
      },
      icon: Icon(
        isSkipped ? Icons.replay : Icons.event_busy_outlined,
        color: isSkipped ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
      label: Text(
        isSkipped
            ? 'Restore (was: ${block.status})'
            : 'Skip this block',
        style: TextStyle(
          color:
              isSkipped ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color: (isSkipped
                  ? theme.colorScheme.primary
                  : theme.colorScheme.error)
              .withValues(alpha: 0.4),
        ),
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

/// Wave 165: small card surfaced at the top of the block-edit form
/// when this block carries a curriculum session slug. Shows the
/// session's category + title with a tap-to-open link back to the
/// session detail in the curriculum surface. For a substitute
/// teacher who opens the block in the moment, this gives a 1-tap
/// path to the full session plan.
class _CurriculumLinkCard extends StatelessWidget {
  const _CurriculumLinkCard({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = findSessionBySlug(slug);
    if (session == null) return const SizedBox.shrink();
    return Material(
      color: session.color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/settings/curricula/photo'),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: session.color, width: 4),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              const Icon(Icons.photo_camera_outlined, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'THROUGH MY EYES · SESSION ${session.number}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: session.color,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to open the session plan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wave 166.2: the "Repeat…" UI block. When the switch is on, the
/// caller spawns N blocks (one per matching weekday between the
/// block's start date and `repeatUntil`).
class _RepeatSection extends StatelessWidget {
  const _RepeatSection({
    required this.startAt,
    required this.endAt,
    required this.repeatOn,
    required this.repeatDays,
    required this.repeatUntil,
    required this.onToggleRepeat,
    required this.onToggleDay,
    required this.onPickUntil,
    required this.expand,
  });

  final DateTime startAt;
  final DateTime endAt;
  final bool repeatOn;
  final List<bool> repeatDays;
  final DateTime repeatUntil;
  final ValueChanged<bool> onToggleRepeat;
  final ValueChanged<int> onToggleDay;
  final VoidCallback onPickUntil;
  final List<DateTime> Function() expand;

  static const _dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _dayFullLabels = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = repeatOn ? expand().length : 0;
    return Material(
      color: repeatOn
          ? scheme.primaryContainer.withValues(alpha: 0.4)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.repeat, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Repeat',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Switch(value: repeatOn, onChanged: onToggleRepeat),
              ],
            ),
            if (repeatOn) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Spawn the same block on every matching day between '
                  'now and the end date. Each instance is independent — '
                  "editing one won't affect the others.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'ON THESE DAYS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < 7; i++)
                    FilterChip(
                      selected: repeatDays[i],
                      label: Text(_dayLabels[i]),
                      onSelected: (_) => onToggleDay(i),
                      tooltip: _dayFullLabels[i],
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'UNTIL',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: onPickUntil,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(
                  '${repeatUntil.year}-'
                  '${repeatUntil.month.toString().padLeft(2, '0')}-'
                  '${repeatUntil.day.toString().padLeft(2, '0')}',
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      count == 0 ? Icons.warning_amber : Icons.check_circle,
                      size: 18,
                      color: count == 0 ? scheme.error : scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        count == 0
                            ? 'No matching days in this range.'
                            : 'Will spawn $count block${count == 1 ? '' : 's'}.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: count == 0
                              ? scheme.error
                              : scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
