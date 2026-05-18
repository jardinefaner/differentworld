import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal bottom sheet for creating or editing a Group ("Classroom" in v1
/// UI). Includes the "What's tracked" capability section: age band +
/// per-tracking-flag toggles whose defaults come from the age band.
class GroupFormSheet extends ConsumerStatefulWidget {
  const GroupFormSheet({this.group, super.key});

  final Group? group;

  static Future<void> show(BuildContext context, {Group? group}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GroupFormSheet(group: group),
    );
  }

  @override
  ConsumerState<GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends ConsumerState<GroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageRangeController;

  late Capabilities _caps;
  late String _ageBand;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.group != null;

  bool _isDirty() {
    final g = widget.group;
    final capsJson = _caps.setting(GroupCaps.ageBand, _ageBand).toJson();
    if (g == null) {
      return _nameController.text.trim().isNotEmpty ||
          _ageRangeController.text.trim().isNotEmpty;
    }
    return _nameController.text.trim() != g.name ||
        _ageRangeController.text.trim() != (g.ageRange ?? '') ||
        capsJson != g.capabilities;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _ageRangeController = TextEditingController(
      text: widget.group?.ageRange ?? '',
    );
    final initial = widget.group?.caps ?? const Capabilities.empty();
    _ageBand = initial.getString(GroupCaps.ageBand) ?? AgeBands.preschool;
    // Merge age-band defaults under any explicit overrides so checkboxes
    // start at the right state for the chosen band.
    _caps = Capabilities(
      AgeBandDefaults.forBand(_ageBand),
    ).mergedWith(initial.toMap());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageRangeController.dispose();
    super.dispose();
  }

  void _onAgeBandChanged(String? band) {
    if (band == null) return;
    setState(() {
      _ageBand = band;
      // Reset the band-driven flags to the new band's defaults, but
      // preserve flags that aren't band-driven (none yet, but future).
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

    try {
      final actions = ref.read(groupActionsProvider);
      if (_isEdit) {
        await actions.update(
          id: widget.group!.id,
          name: name,
          ageRange: ageRange.isEmpty ? null : ageRange,
          capabilitiesJson: capsToSave,
        );
      } else {
        await actions.create(
          name: name,
          ageRange: ageRange.isEmpty ? null : ageRange,
          capabilitiesJson: capsToSave,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'groups'),
      );
      if (!mounted) return;
      setState(
        () => _error = 'Could not save the classroom. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DismissGuard(
      isDirty: _isDirty,
      child: Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      _isEdit ? 'Edit classroom' : 'New classroom',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      autofocus: !_isEdit,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Classroom name',
                        hintText: 'e.g. Sunshine Room',
                        border: OutlineInputBorder(),
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
                    const SizedBox(height: 20),
                    Text(
                      "What's tracked",
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Defaults come from the age band. Override anything '
                      "that doesn't match this room.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CapSwitch(
                      label: 'Diaper changes',
                      subtitle: 'Log every diaper change',
                      value: _caps.getBool(GroupCaps.tracksDiapers),
                      onChanged: (v) => _setBool(GroupCaps.tracksDiapers, v),
                    ),
                    _CapSwitch(
                      label: 'Naps',
                      subtitle: 'Track start, end, and quality',
                      value: _caps.getBool(GroupCaps.tracksNaps),
                      onChanged: (v) => _setBool(GroupCaps.tracksNaps, v),
                    ),
                    _CapSwitch(
                      label: 'Bottle feeds',
                      subtitle: 'Infants — milk type and volume',
                      value: _caps.getBool(GroupCaps.tracksBottleFeeds),
                      onChanged: (v) =>
                          _setBool(GroupCaps.tracksBottleFeeds, v),
                    ),
                    _CapSwitch(
                      label: 'Detailed meal logs',
                      subtitle: 'Log each meal/snack item and amount',
                      value: _caps.getBool(GroupCaps.tracksMealsDetailed),
                      onChanged: (v) =>
                          _setBool(GroupCaps.tracksMealsDetailed, v),
                    ),
                    _CapSwitch(
                      label: 'Outdoor time',
                      subtitle: 'Sun-safety and weather reminders',
                      value: _caps.getBool(GroupCaps.hasOutdoorTime),
                      onChanged: (v) => _setBool(GroupCaps.hasOutdoorTime, v),
                    ),
                    _CapSwitch(
                      label: 'Field trips',
                      subtitle: 'Trips + permission slips',
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
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(_isEdit ? 'Save' : 'Create'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _CapSwitch extends StatelessWidget {
  const _CapSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
