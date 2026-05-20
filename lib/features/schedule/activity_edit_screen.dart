import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_list_screen.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activities/new` and `/activities/:id`. Authors / edits one
/// activity. Bottom-sticky save (matches the vehicle edit pattern).
class ActivityEditScreen extends ConsumerStatefulWidget {
  const ActivityEditScreen({this.activityId, super.key});

  final String? activityId;

  bool get isEdit => activityId != null;

  @override
  ConsumerState<ActivityEditScreen> createState() =>
      _ActivityEditScreenState();
}

class _ActivityEditScreenState extends ConsumerState<ActivityEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _supplies;
  late final TextEditingController _duration;
  late final TextEditingController _ageMin;
  late final TextEditingController _ageMax;
  late final TextEditingController _maxCapacity;

  String? _locationId;
  bool _isOutdoor = false;
  bool _saving = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _description = TextEditingController();
    _supplies = TextEditingController();
    _duration = TextEditingController();
    _ageMin = TextEditingController();
    _ageMax = TextEditingController();
    _maxCapacity = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _supplies.dispose();
    _duration.dispose();
    _ageMin.dispose();
    _ageMax.dispose();
    _maxCapacity.dispose();
    super.dispose();
  }

  void _seedFromActivity(Activity? a) {
    if (_seeded || a == null) return;
    _name.text = a.name;
    _description.text = a.description ?? '';
    _supplies.text = a.supplies ?? '';
    _duration.text = a.defaultDurationMinutes?.toString() ?? '';
    _ageMin.text = a.ageMin?.toString() ?? '';
    _ageMax.text = a.ageMax?.toString() ?? '';
    _maxCapacity.text = a.maxCapacity?.toString() ?? '';
    _locationId = a.defaultLocationId;
    _isOutdoor = a.isOutdoor == 1;
    _seeded = true;
  }

  bool _isDirty(Activity? base) {
    if (base == null) {
      return _name.text.trim().isNotEmpty ||
          _description.text.trim().isNotEmpty ||
          _supplies.text.trim().isNotEmpty ||
          _duration.text.trim().isNotEmpty ||
          _ageMin.text.trim().isNotEmpty ||
          _ageMax.text.trim().isNotEmpty ||
          _maxCapacity.text.trim().isNotEmpty ||
          _locationId != null ||
          _isOutdoor;
    }
    return _name.text.trim() != base.name ||
        _description.text.trim() != (base.description ?? '') ||
        _supplies.text.trim() != (base.supplies ?? '') ||
        _duration.text.trim() !=
            (base.defaultDurationMinutes?.toString() ?? '') ||
        _ageMin.text.trim() != (base.ageMin?.toString() ?? '') ||
        _ageMax.text.trim() != (base.ageMax?.toString() ?? '') ||
        _maxCapacity.text.trim() != (base.maxCapacity?.toString() ?? '') ||
        _locationId != base.defaultLocationId ||
        _isOutdoor != (base.isOutdoor == 1);
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _saving = true);
    final actions = ref.read(activityActionsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final existingId = widget.activityId;

    String? createdOrEditedId;
    final ok = await runReported(
      library: 'activities',
      messenger: messenger,
      onError: 'Could not save the activity.',
      action: () async {
        final desc = _description.text.trim();
        final sup = _supplies.text.trim();
        if (existingId == null) {
          // Capture the new id so we can pop with it — callers that
          // pushed us inline (the block edit sheet's "+ New activity"
          // sentinel) use the returned value to auto-select the new
          // activity without a second tap.
          createdOrEditedId = await actions.create(
            name: _name.text.trim(),
            description: desc.isEmpty ? null : desc,
            supplies: sup.isEmpty ? null : sup,
            defaultLocationId: _locationId,
            defaultDurationMinutes: int.tryParse(_duration.text.trim()),
            ageMin: int.tryParse(_ageMin.text.trim()),
            ageMax: int.tryParse(_ageMax.text.trim()),
            maxCapacity: int.tryParse(_maxCapacity.text.trim()),
            isOutdoor: _isOutdoor,
          );
        } else {
          createdOrEditedId = existingId;
          await actions.update_(
            id: existingId,
            name: _name.text.trim(),
            description: desc.isEmpty ? null : desc,
            supplies: sup.isEmpty ? null : sup,
            defaultLocationId: _locationId,
            defaultDurationMinutes: int.tryParse(_duration.text.trim()),
            ageMin: int.tryParse(_ageMin.text.trim()),
            ageMax: int.tryParse(_ageMax.text.trim()),
            maxCapacity: int.tryParse(_maxCapacity.text.trim()),
            isOutdoor: _isOutdoor,
          );
        }
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop<String>(createdOrEditedId);
  }

  Future<void> _archive() async {
    final id = widget.activityId;
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive this activity?'),
        content: const Text(
          "It won't appear in the activity picker anymore, but any "
          'schedule blocks already using it keep working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final navigator = Navigator.of(context);
    await ref.read(activityActionsProvider).archive(id);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activityAsync = widget.isEdit
        ? ref.watch(activityByIdProvider(widget.activityId!))
        : const AsyncValue<Activity?>.data(null);
    final base = (activityAsync..whenData(_seedFromActivity)).value;

    final locationsAsync = ref.watch(locationsProvider);
    final locations = locationsAsync.value ?? const <Location>[];

    return DismissGuard(
      isDirty: () => _isDirty(base),
      child: EdgeScaffold(
        backFallbackRoute: '/activities',
        body: activityAsync.when(
          loading: () => const LoadingSlot(),
          error: (_, _) =>
              const Center(child: Text('Could not load activity.')),
          data: (a) {
            if (widget.isEdit && a == null) {
              return const Center(child: Text('Activity not found.'));
            }
            return Stack(
              children: [
                Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 96),
                    children: [
                      ContentHeader(
                        title:
                            widget.isEdit ? 'Edit activity' : 'New activity',
                        subtitle: widget.isEdit
                            ? null
                            : 'Something kids can do during a block.',
                        topGap: 0,
                        bottomGap: 12,
                      ),
                      TextFormField(
                        controller: _name,
                        autofocus: !widget.isEdit,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'Swimming · Archery · Art project',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                          hintText:
                              'What happens? What do parents see when they '
                              'tap the block?',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Defaults',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Used when this activity drops onto a block. '
                        'Each can be overridden per-block.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: _locationId,
                        decoration: const InputDecoration(
                          labelText: 'Default location',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            child: Text('— no default —'),
                          ),
                          for (final l in locations)
                            DropdownMenuItem<String?>(
                              value: l.id,
                              child: Text(l.name),
                            ),
                          // "+ New location" — same inline-create
                          // pattern as the block edit sheet, so a
                          // teacher building their activity catalog
                          // never has to leave to add a location.
                          DropdownMenuItem<String?>(
                            value: '__new__',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.add,
                                  size: 16,
                                  color: scheme.primary,
                                ),
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
                          if (v == '__new__') {
                            final newId =
                                await openLocationEditSheet(context);
                            if (!mounted || newId == null) return;
                            setState(() => _locationId = newId);
                            return;
                          }
                          setState(() => _locationId = v);
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _duration,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Default duration',
                                suffixText: 'min',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _maxCapacity,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Max kids',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _ageMin,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Age min',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _ageMax,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Age max',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Outdoor activity'),
                        subtitle: const Text(
                          'Feeds the weather pivot when we ship rain plans.',
                        ),
                        value: _isOutdoor,
                        onChanged: (v) => setState(() => _isOutdoor = v),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _supplies,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Supplies (optional)',
                          hintText:
                              'Swimsuit · towel · water bottle · sunscreen',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (widget.isEdit && a != null) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: DestructiveButton(
                            label: 'Archive activity',
                            icon: Icons.archive_outlined,
                            onPressed: _saving ? null : _archive,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      color: scheme.surface,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
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
                          label: Text(
                            widget.isEdit ? 'Save changes' : 'Create activity',
                          ),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
