import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/breakpoints.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/cap_switch.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full-screen "Edit classroom" / "New classroom" — promoted from the
/// former GroupFormSheet. The per-classroom tracking toggles
/// (diapers / naps / meals / outdoor / field trips) are persistent
/// settings; they don't belong inside a swipe-dismissible overlay.
///
/// Routes:
/// - `/groups/new` — create
/// - `/groups/:id/edit` — edit
class GroupEditScreen extends ConsumerStatefulWidget {
  const GroupEditScreen({this.groupId, super.key});

  final String? groupId;

  bool get isEdit => groupId != null;

  @override
  ConsumerState<GroupEditScreen> createState() => _GroupEditScreenState();
}

class _GroupEditScreenState extends ConsumerState<GroupEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageRangeController;
  late final TextEditingController _capacity;
  late final TextEditingController _ratio;

  Capabilities _caps = const Capabilities.empty();
  String _ageBand = AgeBands.preschool;

  bool _saving = false;
  String? _error;
  bool _seeded = false; // seeded from stream on first arrival (edit mode)

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageRangeController = TextEditingController();
    _capacity = TextEditingController();
    _ratio = TextEditingController();
    if (!widget.isEdit) {
      _caps = Capabilities(AgeBandDefaults.forBand(_ageBand));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageRangeController.dispose();
    _capacity.dispose();
    _ratio.dispose();
    super.dispose();
  }

  void _seedFromGroup(Group? g) {
    if (_seeded || g == null) return;
    _nameController.text = g.name;
    _ageRangeController.text = g.ageRange ?? '';
    final initial = g.caps;
    _ageBand = initial.getString(GroupCaps.ageBand) ?? AgeBands.preschool;
    _capacity.text =
        initial.getInt(GroupCaps.licensedCapacity)?.toString() ?? '';
    _ratio.text =
        initial.getInt(GroupCaps.ratioChildrenPerAdult)?.toString() ?? '';
    _caps = Capabilities(
      AgeBandDefaults.forBand(_ageBand),
    ).mergedWith(initial.toMap());
    _seeded = true;
  }

  bool _isDirty(Group? g) {
    final capsJson = _caps.setting(GroupCaps.ageBand, _ageBand).toJson();
    if (g == null) {
      return _nameController.text.trim().isNotEmpty ||
          _ageRangeController.text.trim().isNotEmpty;
    }
    return _nameController.text.trim() != g.name ||
        _ageRangeController.text.trim() != (g.ageRange ?? '') ||
        capsJson != g.capabilities;
  }

  void _onAgeBandChanged(String? band) {
    if (band == null) return;
    setState(() {
      _ageBand = band;
      final defaults = AgeBandDefaults.forBand(band);
      _caps = _caps.setting(GroupCaps.ageBand, band).mergedWith(defaults);
    });
  }

  void _setBool(String key, bool value) {
    setState(() => _caps = _caps.setting(key, value));
  }

  /// Set (or clear) one of the room's regulated numbers. An empty field
  /// CLEARS the key rather than storing 0 — "not set" and "a limit of zero"
  /// are different states, and only one of them is a real room.
  void _setNumber(String key, String raw) {
    final trimmed = raw.trim();
    final parsed = int.tryParse(trimmed);
    setState(() {
      _caps = _caps.setting(
        key,
        trimmed.isEmpty || parsed == null || parsed <= 0 ? null : parsed,
      );
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController.text.trim();
    final ageRange = _ageRangeController.text.trim();
    final capsToSave = _caps.setting(GroupCaps.ageBand, _ageBand).toJson();

    setState(() {
      _saving = true;
      _error = null;
    });

    final actions = ref.read(groupActionsProvider);
    final ok = await runReported(
      library: 'groups',
      action: () => widget.isEdit
          ? actions.update(
              id: widget.groupId!,
              name: name,
              ageRange: ageRange.isEmpty ? null : ageRange,
              capabilitiesJson: capsToSave,
            )
          : actions.create(
              name: name,
              ageRange: ageRange.isEmpty ? null : ageRange,
              capabilitiesJson: capsToSave,
            ),
    );
    if (!mounted) return;
    if (ok) {
      context.pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Could not save the classroom. Please try again.';
    });
  }

  /// Retire a room without destroying it — the action a director actually
  /// wants at the end of a year (docs/ROOMS.md).
  Future<void> _close() async {
    if (!ref.read(viewerProvider).canManageSpace) return;
    if (!widget.isEdit) return;
    final g = ref.read(_groupByIdProvider(widget.groupId!)).value;
    if (g == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: 'Close ${g.name}?',
      message:
          'It stops appearing in today’s rosters, schedules and pickers, '
          'and keeps everything — its schedule, its groupings, its whole '
          'history. You can reopen it any time.',
      confirmLabel: 'Close the room',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final ok = await runReported(
      library: 'groups',
      action: () => ref.read(groupActionsProvider).closeRoom(g.id),
    );
    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('${g.name} closed. Nothing was deleted.')),
      );
      context.pop();
      if (!mounted) return;
      if (context.canPop()) context.pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Could not close the room. Please try again.';
    });
  }

  Future<void> _delete() async {
    if (!ref.read(viewerProvider).canManageSpace) return;
    if (!widget.isEdit) return;
    final g = ref.read(_groupByIdProvider(widget.groupId!)).value;
    if (g == null) return;
    // TRUTHFUL COPY (2026-08-24). This said only that "assignments will be
    // removed" — but SIX tables cascade off groups, so deleting a room also
    // takes its entire schedule, its weekly template blocks, every
    // arrangement and its fairness log. Children genuinely do survive
    // (subjects.group_id is ON DELETE SET NULL), which is why the old copy
    // read as harmless.
    final confirmed = await confirmDestructive(
      context,
      title: 'Erase ${g.name} permanently?',
      message:
          'This is NOT how you retire a room — use Close instead.\n\n'
          'Erasing deletes its whole schedule, its weekly plan, every '
          'grouping it has ever made and its staff assignments. Children '
          'survive but end up in no room at all.',
      confirmLabel: 'Erase permanently',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    final ok = await runReported(
      library: 'groups',
      action: () => ref.read(groupActionsProvider).delete(g.id),
    );
    if (!mounted) return;
    if (ok) {
      // Pop both the edit screen AND the detail beneath (now stale).
      context.pop();
      if (!mounted) return;
      if (context.canPop()) context.pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = 'Could not delete. Please try again.';
    });
  }

  /// The width at which short fields pair up 2-across (tablet portrait
  /// and wider). Below this, the form stays single-column. There's no
  /// shared constant at exactly this value — `Breakpoints.smallTablet`
  /// (840) is the next-nearest — so it lives here, named, for the
  /// "grids everywhere" sweep.
  static const double _twoColMinWidth = 720;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);
    final bento = bentoEnabled(ref, perScreen: null);
    final groupAsync = widget.isEdit
        ? ref.watch(_groupByIdProvider(widget.groupId!))
        : const AsyncValue<Group?>.data(null);
    final groupForDirtyCheck = (groupAsync..whenData(_seedFromGroup)).value;

    return DismissGuard(
      isDirty: () => _isDirty(groupForDirtyCheck),
      child: EdgeScaffold(
        backFallbackRoute: widget.isEdit ? '/groups/${widget.groupId}' : '/',
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
        body: groupAsync.when(
          loading: () => const LoadingSlot(),
          error: (_, _) => ErrorState(
            title: 'Could not load ${labels.group.toLowerCase()}',
            onRetry: () => ref.invalidate(_groupByIdProvider(widget.groupId!)),
          ),
          data: (group) {
            if (widget.isEdit && group == null) {
              return EmptyState(
                icon: Icons.search_off_outlined,
                title: '${labels.group} not found',
                message:
                    'It may have been removed. Go back and pick another '
                    '${labels.group.toLowerCase()}.',
                action: OutlinedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to home'),
                ),
              );
            }
            final groupLower = labels.group.toLowerCase();
            return LayoutBuilder(
              builder: (context, constraints) {
                final twoCol = bento && constraints.maxWidth >= _twoColMinWidth;

                // Each field is built ONCE here and placed into either the
                // single-column Column or the paired 2-column rows below.
                // Same widget instance + stable ValueKey across both layouts,
                // so moving a field between a Column slot and a Row slot can't
                // tear down its TextField IME connection (the keyboard-closes
                // bug from CLAUDE.md).
                final nameField = TextFormField(
                  key: const ValueKey('group-edit-name'),
                  controller: _nameController,
                  autofocus: !widget.isEdit,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: '${labels.group} name',
                    hintText: 'e.g. Sunshine Room',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Required';
                    if (v.length < 2) return 'Too short';
                    return null;
                  },
                );
                final ageBandField = DropdownButtonFormField<String>(
                  key: const ValueKey('group-edit-age-band'),
                  initialValue: _ageBand,
                  decoration: const InputDecoration(
                    labelText: 'Age band',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final band in AgeBands.all)
                      DropdownMenuItem(
                        value: band,
                        child: Text(AgeBands.label(band)),
                      ),
                  ],
                  onChanged: _onAgeBandChanged,
                );
                final ageRangeField = TextFormField(
                  key: const ValueKey('group-edit-age-range'),
                  controller: _ageRangeController,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Age range label (optional)',
                    hintText: 'e.g. 3–4 years',
                    border: OutlineInputBorder(),
                  ),
                );

                // The two regulated numbers (docs/ROOMS.md). Per-room, not
                // per-program, because they are set by age band: an infant
                // room and an 8-12 room in one building carry completely
                // different limits.
                final capacityField = TextField(
                  key: const ValueKey('group-edit-capacity'),
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Licensed capacity',
                    hintText: 'How many children this room may hold',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => _setNumber(GroupCaps.licensedCapacity, v),
                );
                final ratioField = TextField(
                  key: const ValueKey('group-edit-ratio'),
                  controller: _ratio,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Children per adult',
                    hintText: 'e.g. 8 for 1:8',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      _setNumber(GroupCaps.ratioChildrenPerAdult, v),
                );

                // Capability toggles — short, pairable in 2-col mode.
                final diapersSwitch = CapSwitch(
                  key: const ValueKey('group-edit-cap-diapers'),
                  label: 'Diaper changes',
                  subtitle: 'Log every diaper change',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.tracksDiapers),
                  onChanged: (v) => _setBool(GroupCaps.tracksDiapers, v),
                );
                final napsSwitch = CapSwitch(
                  key: const ValueKey('group-edit-cap-naps'),
                  label: 'Naps',
                  subtitle: 'Track start, end, and quality',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.tracksNaps),
                  onChanged: (v) => _setBool(GroupCaps.tracksNaps, v),
                );
                final bottleSwitch = CapSwitch(
                  key: const ValueKey('group-edit-cap-bottle'),
                  label: 'Bottle feeds',
                  subtitle: 'Infants — milk type and volume',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.tracksBottleFeeds),
                  onChanged: (v) => _setBool(GroupCaps.tracksBottleFeeds, v),
                );
                final mealsSwitch = CapSwitch(
                  key: const ValueKey('group-edit-cap-meals'),
                  label: 'Detailed meal logs',
                  subtitle: 'Log each meal/snack item and amount',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.tracksMealsDetailed),
                  onChanged: (v) => _setBool(GroupCaps.tracksMealsDetailed, v),
                );
                final outdoorSwitch = CapSwitch(
                  key: const ValueKey('group-edit-cap-outdoor'),
                  label: 'Outdoor time',
                  subtitle: 'Sun-safety and weather reminders',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.hasOutdoorTime),
                  onChanged: (v) => _setBool(GroupCaps.hasOutdoorTime, v),
                );
                final fieldTripsSwitch = CapSwitch(
                  key: const ValueKey('group-edit-cap-field-trips'),
                  label: 'Field trips',
                  subtitle: 'Trips + permission slips',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.hasFieldTrips),
                  onChanged: (v) => _setBool(GroupCaps.hasFieldTrips, v),
                );

                final formChildren = twoCol
                    ? <Widget>[
                        _row(nameField, ageBandField),
                        const SizedBox(height: 12),
                        // Age range pairs with capacity so the row stays
                        // half-width aligned with the one above.
                        _row(ageRangeField, capacityField),
                        const SizedBox(height: 12),
                        _row(ratioField, const SizedBox.shrink()),
                      ]
                    : [
                        nameField,
                        const SizedBox(height: 12),
                        ageBandField,
                        const SizedBox(height: 12),
                        ageRangeField,
                        const SizedBox(height: 12),
                        capacityField,
                        const SizedBox(height: 12),
                        ratioField,
                      ];

                final capChildren = twoCol
                    ? <Widget>[
                        _row(diapersSwitch, napsSwitch),
                        _row(bottleSwitch, mealsSwitch),
                        _row(outdoorSwitch, fieldTripsSwitch),
                      ]
                    : [
                        diapersSwitch,
                        napsSwitch,
                        bottleSwitch,
                        mealsSwitch,
                        outdoorSwitch,
                        fieldTripsSwitch,
                      ];

                return FormBody(
                  // Widen the column so two fields fit side by side; the
                  // single-column form stays at the comfortable reading width.
                  maxWidth: twoCol ? 900 : Breakpoints.contentMaxWidth,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    ContentHeader(
                      title: widget.isEdit
                          ? 'Edit $groupLower'
                          : 'New $groupLower',
                      subtitle: widget.isEdit
                          ? null
                          : 'Add a $groupLower to this '
                                '${labels.space.toLowerCase()}',
                    ),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: formChildren,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text("What's tracked", style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Defaults come from the age band. Override anything '
                      "that doesn't match this room.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...capChildren,
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (widget.isEdit &&
                        ref.watch(viewerProvider).canManageSpace) ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        // Close leads; erase is the small print underneath.
                        // Retiring a room is the common act at year end;
                        // erasing one is a mistake being corrected.
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _close,
                              icon: const Icon(Icons.archive_outlined),
                              label: const Text('Close this room'),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Keeps everything — the schedule, the '
                              'groupings, the whole history.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            DestructiveButton(
                              label: 'Erase permanently',
                              onPressed: _saving ? null : _delete,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 64),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// Lay two short fields side by side, each taking half the width with
  /// a gap between. Used only in the 2-column (bento + wide) layout. The
  /// children keep their own `ValueKey`s, so the pairing is purely visual.
  Widget _row(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _groupByIdProvider = StreamProvider.autoDispose.family<Group?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.groupsDao.watchById(id);
  },
);
