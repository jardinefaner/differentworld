import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/cap_switch.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
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
    if (!widget.isEdit) {
      _caps = Capabilities(AgeBandDefaults.forBand(_ageBand));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageRangeController.dispose();
    super.dispose();
  }

  void _seedFromGroup(Group? g) {
    if (_seeded || g == null) return;
    _nameController.text = g.name;
    _ageRangeController.text = g.ageRange ?? '';
    final initial = g.caps;
    _ageBand = initial.getString(GroupCaps.ageBand) ?? AgeBands.preschool;
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

  Future<void> _delete() async {
    if (!ref.read(viewerProvider).canManageSpace) return;
    if (!widget.isEdit) return;
    final g = ref.read(_groupByIdProvider(widget.groupId!)).value;
    if (g == null) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this classroom?',
      message:
          '${g.name} and its assignments will be removed for everyone '
          "on your team. Students stay; they just won't be in a classroom.",
      confirmLabel: 'Delete classroom',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);
    final groupAsync = widget.isEdit
        ? ref.watch(_groupByIdProvider(widget.groupId!))
        : const AsyncValue<Group?>.data(null);
    final groupForDirtyCheck =
        (groupAsync..whenData(_seedFromGroup)).value;

    return DismissGuard(
      isDirty: () => _isDirty(groupForDirtyCheck),
      child: EdgeScaffold(
        backFallbackRoute:
            widget.isEdit ? '/groups/${widget.groupId}' : '/',
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
          error: (_, _) => Center(
            child: Text('Could not load ${labels.group.toLowerCase()}.'),
          ),
          data: (group) {
            if (widget.isEdit && group == null) {
              return Center(
                child: Text('${labels.group} not found.'),
              );
            }
            final groupLower = labels.group.toLowerCase();
            return FormBody(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ContentHeader(
                  title: widget.isEdit
                      ? 'Edit $groupLower'
                      : 'New $groupLower',
                  subtitle: widget.isEdit
                      ? null
                      : 'Add a $groupLower to this ${labels.space.toLowerCase()}',
                ),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
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
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
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
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _ageRangeController,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Age range label (optional)',
                          hintText: 'e.g. 3–4 years',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
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
                CapSwitch(
                  label: 'Diaper changes',
                  subtitle: 'Log every diaper change',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.tracksDiapers),
                  onChanged: (v) => _setBool(GroupCaps.tracksDiapers, v),
                ),
                CapSwitch(
                  label: 'Naps',
                  subtitle: 'Track start, end, and quality',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.tracksNaps),
                  onChanged: (v) => _setBool(GroupCaps.tracksNaps, v),
                ),
                CapSwitch(
                  label: 'Bottle feeds',
                  subtitle: 'Infants — milk type and volume',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.tracksBottleFeeds),
                  onChanged: (v) => _setBool(GroupCaps.tracksBottleFeeds, v),
                ),
                CapSwitch(
                  label: 'Detailed meal logs',
                  subtitle: 'Log each meal/snack item and amount',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.tracksMealsDetailed),
                  onChanged: (v) =>
                      _setBool(GroupCaps.tracksMealsDetailed, v),
                ),
                CapSwitch(
                  label: 'Outdoor time',
                  subtitle: 'Sun-safety and weather reminders',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.hasOutdoorTime),
                  onChanged: (v) => _setBool(GroupCaps.hasOutdoorTime, v),
                ),
                CapSwitch(
                  label: 'Field trips',
                  subtitle: 'Trips + permission slips',
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _caps.getBool(GroupCaps.hasFieldTrips),
                  onChanged: (v) => _setBool(GroupCaps.hasFieldTrips, v),
                ),
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
                    child: DestructiveButton(
                      label: 'Delete classroom',
                      onPressed: _saving ? null : _delete,
                    ),
                  ),
                ],
                const SizedBox(height: 64),
              ],
            );
          },
        ),
      ),
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
