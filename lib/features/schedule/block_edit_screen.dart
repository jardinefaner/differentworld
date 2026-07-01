import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/curricula/photo_curriculum.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/omnibox/compose_draft_seed.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/activity_edit_screen.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Sentinel used as the dropdown value for "+ New …" rows. A real
/// uuid never collides. Dropdowns intercept this and push the
/// relevant edit screen inline, then auto-select the new id when
/// the user returns.
const String _kSentinelNew = '__new__';

/// Picker-sheet sentinel for the "none / default / unassigned" row.
const String _kSentinelNone = '__none__';

/// Emoji + label + icon per block kind — shared by the preview hero and the
/// type chips so both read the same.
String _kindEmoji(String kind) => switch (kind) {
  BlockKind.fieldTrip => '🚌',
  BlockKind.breakBlock => '☕',
  BlockKind.closed => '🚫',
  _ => '🎨',
};

String _kindLabel(String kind) => switch (kind) {
  BlockKind.fieldTrip => 'Field trip',
  BlockKind.breakBlock => 'Break',
  BlockKind.closed => 'Closed',
  _ => 'Activity',
};

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
  final _name = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  /// Snapshot of every field's initial value, captured at the end of
  /// [initState]. `_isDirty` compares the live state to this so `DismissGuard`
  /// only prompts when the user has actually changed something.
  late final String _initialSnapshot;

  String _snapshot() => [
    _kind,
    _startAt.toIso8601String(),
    _endAt.toIso8601String(),
    _activityId,
    _leadMemberId,
    _locationOverrideId,
    _name.text,
    _notes.text,
    _repeatOn,
    _repeatDays.join(','),
    _repeatUntil.toIso8601String(),
  ].join('|');

  bool get _isDirty => _snapshot() != _initialSnapshot;

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
        // The clean session title is the block's NAME; the link card above the
        // form carries the "Session N · Through My Eyes" detail.
        _name.text = session.title;
        // Photo sessions trend ~30 min total. Keep the start the
        // user picked, bump the end out from the default 60 min.
        _endAt = _startAt.add(const Duration(minutes: 30));
      }
      // "Omnibox composes": a phrase like "field trip to the pond Friday"
      // arrives here as a one-shot seed (kind + note) alongside the parsed
      // start (which rode in via defaultStart). A curriculum CTA wins if both
      // somehow set — they never do in practice.
      final seed = ref.read(pendingBlockDraftProvider);
      if (seed != null) {
        if (_curriculumSlug == null) {
          _kind = seed.kind;
          if (seed.title.isNotEmpty) _name.text = seed.title;
        }
        // Consume-once, ALWAYS (even the curriculum-coexist edge) so the seed
        // can't poison a later plain create. Deferred through a microtask:
        // nothing watches this provider today, but the defer keeps the clear
        // out of the build phase in case a watcher is ever added (CLAUDE.md
        // "modified provider while the widget tree was building").
        unawaited(
          Future.microtask(() {
            if (!mounted) return;
            ref.read(pendingBlockDraftProvider.notifier).draft = null;
          }),
        );
      }
    } else {
      _kind = e.kind;
      _startAt = DateTime.parse(e.startAt).toLocal();
      _endAt = DateTime.parse(e.endAt).toLocal();
      _activityId = e.activityId;
      _leadMemberId = e.leadMemberId;
      _locationOverrideId = e.locationOverrideId;
      _name.text = e.title ?? '';
      _notes.text = e.notes ?? '';
      _curriculumSlug = e.curriculumSessionSlug;
    }
    // Baseline for the dismiss guard — taken AFTER all prefill (curriculum /
    // compose seed / existing) so a freshly-drafted block isn't "dirty" until
    // the user actually touches it.
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _name.dispose();
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
        final wasDefault =
            _endAt.difference(_startAt).inMinutes == 60 ||
            (widget.existing != null && widget.existing!.activityId == null);
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
    if (picked == null || !mounted) return;
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
    if (picked == null || !mounted) return;
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
    final last = DateTime(
      _repeatUntil.year,
      _repeatUntil.month,
      _repeatUntil.day,
    );
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
        final name = _name.text.trim();
        final title = name.isEmpty ? null : name;
        final activityId =
            _kind == BlockKind.onSite || _kind == BlockKind.fieldTrip
            ? _activityId
            : null;
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
              title: title,
              activityId: activityId,
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
              title: title,
              activityId: activityId,
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
            title: title,
            startAt: _startAt,
            endAt: _endAt,
            activityId: activityId,
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
    final ok = await confirmDestructive(
      context,
      title: 'Delete this block?',
      message: "It will be removed from this cohort's day.",
    );
    if (!ok || !mounted) return;
    final goRouter = GoRouter.of(context);
    await ref.read(scheduleActionsProvider).delete_(id);
    if (!mounted) return;
    if (goRouter.canPop()) goRouter.pop();
  }

  /// Set the block's length from a quick-duration chip — keep the start, move
  /// the end.
  void _setDuration(int minutes) {
    setState(() => _endAt = _startAt.add(Duration(minutes: minutes)));
  }

  /// A clean list picker on a glass sheet (replaces the boxy dropdowns). Returns
  /// the chosen row's value (an id, [_kSentinelNone], or [_kSentinelNew]), or
  /// null if dismissed.
  Future<String?> _pickSheet({
    required String title,
    required List<({String value, String label, bool selected})> rows,
  }) {
    // Dismiss the keyboard explicitly first — if the Name field held focus,
    // opening the sheet would drop it as a side-effect. Making it intentional
    // keeps the interaction clean.
    FocusManager.instance.primaryFocus?.unfocus();
    return showGlassSheet<String>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final r in rows)
                      ListTile(
                        title: Text(
                          r.label,
                          style: r.value == _kSentinelNew
                              ? TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                )
                              : null,
                        ),
                        trailing: r.selected
                            ? Icon(Icons.check, color: scheme.primary)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(r.value),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickActivity(List<Activity> activities) async {
    final picked = await _pickSheet(
      title: 'Activity',
      rows: [
        (
          value: _kSentinelNone,
          label: 'No activity',
          selected: _activityId == null,
        ),
        for (final a in activities.where(
          (x) => x.archivedAt == null || x.id == _activityId,
        ))
          (
            value: a.id,
            label: a.archivedAt == null ? a.name : '${a.name} (archived)',
            selected: a.id == _activityId,
          ),
        (value: _kSentinelNew, label: '+ New activity', selected: false),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked == _kSentinelNone) {
      setState(() => _activityId = null);
      return;
    }
    if (picked == _kSentinelNew) {
      final newId = await Navigator.of(context).push<String?>(
        MaterialPageRoute(builder: (_) => const ActivityEditScreen()),
      );
      if (!mounted || newId == null) return;
      // Select it immediately (robust: the new row may not have streamed into
      // allActivitiesProvider yet), then apply its defaults if it has.
      setState(() => _activityId = newId);
      final fresh = ref.read(allActivitiesProvider).value ?? const <Activity>[];
      _applyActivityDefaults(newId, fresh);
      return;
    }
    _applyActivityDefaults(picked, activities);
  }

  Future<void> _pickLead(List<Member> members) async {
    final picked = await _pickSheet(
      title: 'Lead',
      rows: [
        (
          value: _kSentinelNone,
          label: 'Unassigned',
          selected: _leadMemberId == null,
        ),
        for (final m in members)
          (
            value: m.id,
            label: m.displayName,
            selected: m.id == _leadMemberId,
          ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(
      () => _leadMemberId = picked == _kSentinelNone ? null : picked,
    );
  }

  Future<void> _pickLocation(List<Location> locations) async {
    final picked = await _pickSheet(
      title: 'Location',
      rows: [
        (
          value: _kSentinelNone,
          label: 'Activity default',
          selected: _locationOverrideId == null,
        ),
        for (final l in locations)
          (
            value: l.id,
            label: l.name,
            selected: l.id == _locationOverrideId,
          ),
        (value: _kSentinelNew, label: '+ New location', selected: false),
      ],
    );
    if (picked == null || !mounted) return;
    if (picked == _kSentinelNew) {
      final newId = await context.push<String?>('/settings/locations/new');
      if (!mounted || newId == null) return;
      setState(() => _locationOverrideId = newId);
      return;
    }
    setState(
      () => _locationOverrideId = picked == _kSentinelNone ? null : picked,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activities =
        ref.watch(allActivitiesProvider).value ?? const <Activity>[];
    final locations = ref.watch(locationsProvider).value ?? const <Location>[];
    final members = ref.watch(membersInSpaceProvider).value ?? const <Member>[];
    final groupName = ref
        .watch(groupsProvider)
        .value
        ?.where((g) => g.id == widget.groupId)
        .firstOrNull
        ?.name;

    // Resolved labels for the Detail rows.
    final activity = _activityId == null
        ? null
        : activities.where((a) => a.id == _activityId).firstOrNull;
    final lead = _leadMemberId == null
        ? null
        : members.where((m) => m.id == _leadMemberId).firstOrNull;
    final locOverride = _locationOverrideId == null
        ? null
        : locations.where((l) => l.id == _locationOverrideId).firstOrNull;
    final durationMin = _endAt.difference(_startAt).inMinutes;
    final showActivity =
        _kind == BlockKind.onSite || _kind == BlockKind.fieldTrip;
    final showLeadLoc = _kind != BlockKind.closed;

    return DismissGuard(
      isDirty: () => _isDirty,
      child: EdgeScaffold(
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
            if (_curriculumSlug != null) ...[
              _CurriculumLinkCard(slug: _curriculumSlug!),
              const SizedBox(height: 12),
            ],
            _BlockPreview(
              nameCtrl: _name,
              kind: _kind,
              start: _startAt,
              end: _endAt,
              groupName: groupName,
            ),
            const SizedBox(height: 18),
            const _FieldLabel('Name'),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('block-name-field'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: switch (_kind) {
                  BlockKind.fieldTrip => 'The pond · The zoo',
                  BlockKind.breakBlock => 'Snack · Lunch · Rest',
                  BlockKind.closed => 'Holiday · Closed',
                  _ => "What's this block?",
                },
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('Type'),
            const SizedBox(height: 6),
            _TypeChips(
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('When'),
            const SizedBox(height: 6),
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
            const SizedBox(height: 8),
            _DurationChips(durationMin: durationMin, onPick: _setDuration),
            if (showActivity || showLeadLoc) ...[
              const SizedBox(height: 16),
              const _FieldLabel('Details'),
              const SizedBox(height: 6),
              _DetailsCard(
                rows: [
                  if (showActivity)
                    _DetailRow(
                      icon: Icons.palette_outlined,
                      label: 'Activity',
                      value: activity?.name ?? 'Pick one',
                      muted: activity == null,
                      onTap: () => _pickActivity(activities),
                    ),
                  if (showLeadLoc)
                    _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Lead',
                      value: lead?.displayName ?? 'Unassigned',
                      muted: lead == null,
                      onTap: () => _pickLead(members),
                    ),
                  if (showLeadLoc)
                    _DetailRow(
                      icon: Icons.place_outlined,
                      label: 'Location',
                      value: locOverride?.name ?? 'Activity default',
                      muted: locOverride == null,
                      onTap: () => _pickLocation(locations),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _FieldLabel(_kind == BlockKind.closed ? 'Reason' : 'Notes'),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('block-notes-field'),
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _kind == BlockKind.closed
                    ? 'Holiday · weather · maintenance'
                    : 'Anything staff or parents should see',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
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
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
    final isSkipped =
        block.status == BlockStatus.skipped ||
        block.status == BlockStatus.cancelled;
    return OutlinedButton.icon(
      onPressed: () async {
        if (isSkipped) {
          await ref
              .read(scheduleActionsProvider)
              .setBlockStatus(
                id: block.id,
                status: BlockStatus.planned,
              );
          if (context.mounted) await Navigator.of(context).maybePop();
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
                  onPressed: () => Navigator.of(ctx).pop(),
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
        await ref
            .read(scheduleActionsProvider)
            .setBlockStatus(
              id: block.id,
              status: BlockStatus.skipped,
              reason: reason.isEmpty ? null : reason,
            );
        if (context.mounted) await Navigator.of(context).maybePop();
      },
      icon: Icon(
        isSkipped ? Icons.replay : Icons.event_busy_outlined,
        color: isSkipped ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
      label: Text(
        isSkipped ? 'Restore (was: ${block.status})' : 'Skip this block',
        style: TextStyle(
          color: isSkipped
              ? theme.colorScheme.primary
              : theme.colorScheme.error,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        side: BorderSide(
          color:
              (isSkipped ? theme.colorScheme.primary : theme.colorScheme.error)
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
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
                          color: count == 0 ? scheme.error : scheme.onSurface,
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

/// A small tracked caps section label above each field group.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// The live "this block" hero at the top of the editor — the block taking
/// shape as you edit (echoes the omnibox draft card, so the editor reads as the
/// same system). Rebuilds its name live off the controller.
class _BlockPreview extends StatelessWidget {
  const _BlockPreview({
    required this.nameCtrl,
    required this.kind,
    required this.start,
    required this.end,
    required this.groupName,
  });

  final TextEditingController nameCtrl;
  final String kind;
  final DateTime start;
  final DateTime end;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: nameCtrl,
      builder: (context, _) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final name = nameCtrl.text.trim();
        final title = name.isEmpty ? _kindLabel(kind) : name;
        final timeLabel =
            '${TimeOfDay.fromDateTime(start).format(context)} – '
            '${TimeOfDay.fromDateTime(end).format(context)}';
        final sub = [
          _kindLabel(kind),
          timeLabel,
          ?groupName,
        ].join(' · ');
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(_kindEmoji(kind), style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The block-kind picker as four pill chips (replaces the M3 segmented button).
class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const kinds = [
      BlockKind.onSite,
      BlockKind.fieldTrip,
      BlockKind.breakBlock,
      BlockKind.closed,
    ];
    return Row(
      children: [
        for (var i = 0; i < kinds.length; i++) ...[
          if (i > 0) const SizedBox(width: 7),
          Expanded(
            child: _TypeChip(
              label: switch (kinds[i]) {
                BlockKind.fieldTrip => 'Trip',
                BlockKind.breakBlock => 'Break',
                BlockKind.closed => 'Closed',
                _ => 'Activity',
              },
              selected: kinds[i] == selected,
              onTap: () => onChanged(kinds[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The current length plus quick-set duration chips. A [Wrap] (not a Row) so it
/// can never overflow at large text scales.
class _DurationChips extends StatelessWidget {
  const _DurationChips({required this.durationMin, required this.onPick});

  final int durationMin;
  final ValueChanged<int> onPick;

  static String _fmt(int m) => m <= 0
      ? '0m'
      : m % 60 == 0
      ? '${m ~/ 60}h'
      : m < 60
      ? '${m}m'
      : '${m ~/ 60}h ${m % 60}m';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const presets = [30, 45, 60, 90];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: Text(
            _fmt(durationMin),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final p in presets)
          _DurChip(
            label: _fmt(p),
            selected: p == durationMin,
            onTap: () => onPick(p),
          ),
      ],
    );
  }
}

class _DurChip extends StatelessWidget {
  const _DurChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Activity / Lead / Location rows in one card (replaces the three stacked
/// bordered dropdowns). Each row opens a picker sheet.
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 44,
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.bodyLarge),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
