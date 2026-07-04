import 'package:differentworld/features/vehicles/vehicle_photo_shots.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// `/vehicles/:id/photo-checklist` — the per-vehicle guided-photo editor
/// (docs/VISION.md vehicle tangent; the "configurable" half). A director sets
/// exactly what to shoot at check-out and check-in for THIS vehicle: reorder,
/// add, remove, rename, toggle required. Saved into `vehicles.capabilities`.
///
/// The empty-cabin check-in shot is LOCKED — it can't be removed or made
/// optional (the safety floor; `shotsFor` re-appends it regardless).
class VehiclePhotoShotsEditScreen extends ConsumerStatefulWidget {
  const VehiclePhotoShotsEditScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<VehiclePhotoShotsEditScreen> createState() =>
      _VehiclePhotoShotsEditScreenState();
}

class _VehiclePhotoShotsEditScreenState
    extends ConsumerState<VehiclePhotoShotsEditScreen> {
  List<VehiclePhotoShot>? _checkout;
  List<VehiclePhotoShot>? _checkin;
  bool _saving = false;

  void _ensureLoaded(String capabilitiesJson) {
    _checkout ??= shotsFor(capabilitiesJson, 'checkout');
    _checkin ??= shotsFor(capabilitiesJson, 'checkin');
  }

  bool _locked(String kind, VehiclePhotoShot s) =>
      kind == 'checkin' && s.key == emptyCabinShot.key;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      var caps =
          ref.read(vehicleByIdProvider(widget.vehicleId)).value?.capabilities ??
          '{}';
      caps = withPhotoShots(caps, 'checkout', _checkout ?? const []);
      caps = withPhotoShots(caps, 'checkin', _checkin ?? const []);
      await ref
          .read(vehicleActionsProvider)
          .setCapabilities(widget.vehicleId, caps);
      if (!mounted) return;
      context.pop();
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save the photo checklist.")),
      );
    }
  }

  Future<void> _editShot(String kind, int? index) async {
    final existing = index == null ? null : _listFor(kind)[index];
    final result = await showDialog<VehiclePhotoShot>(
      context: context,
      builder: (_) => _ShotDialog(shot: existing),
    );
    if (result == null || !mounted) return;
    setState(() {
      final list = _listFor(kind);
      if (index == null) {
        list.add(result);
      } else {
        list[index] = result;
      }
    });
  }

  List<VehiclePhotoShot> _listFor(String kind) =>
      (kind == 'checkin' ? _checkin : _checkout)!;

  void _resetDefaults(String kind) {
    setState(() {
      if (kind == 'checkin') {
        _checkin = defaultShotsFor('checkin');
      } else {
        _checkout = defaultShotsFor('checkout');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vehicleAsync = ref.watch(vehicleByIdProvider(widget.vehicleId));
    return EdgeScaffold(
      backFallbackRoute: '/vehicles/${widget.vehicleId}',
      actions: [
        PrimaryActionButton(
          tooltip: 'Save',
          icon: Icons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
      body: vehicleAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => const ErrorState(title: 'Could not load vehicle'),
        data: (v) {
          if (v == null) {
            return const EmptyState(
              icon: Icons.directions_car_outlined,
              title: 'Vehicle not found',
            );
          }
          _ensureLoaded(v.capabilities);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              ContentHeader(
                title: 'Photo checklist',
                subtitle: '${v.name} · what to photograph at check-out & in',
              ),
              _section('Check-out', 'checkout', _checkout!),
              const SizedBox(height: 24),
              _section('Check-in', 'checkin', _checkin!),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, String kind, List<VehiclePhotoShot> shots) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => _resetDefaults(kind),
              child: const Text('Reset'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: shots.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              var ni = newIndex;
              if (ni > oldIndex) ni -= 1;
              final item = shots.removeAt(oldIndex);
              shots.insert(ni, item);
            });
          },
          itemBuilder: (context, i) {
            final s = shots[i];
            final locked = _locked(kind, s);
            return Card(
              key: ValueKey('${kind}_${s.key}'),
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: locked
                    ? Icon(
                        Icons.lock_outline,
                        color: Theme.of(context).colorScheme.tertiary,
                      )
                    : ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                title: Text(s.label),
                subtitle: s.hint.isEmpty ? null : Text(s.hint),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Required',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    if (!locked)
                      IconButton(
                        tooltip: 'Remove',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => shots.removeAt(i)),
                      ),
                  ],
                ),
                onTap: locked ? null : () => _editShot(kind, i),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _editShot(kind, null),
            icon: const Icon(Icons.add),
            label: const Text('Add a shot'),
          ),
        ),
      ],
    );
  }
}

/// Add / edit one shot — label, hint, required.
class _ShotDialog extends StatefulWidget {
  const _ShotDialog({this.shot});

  final VehiclePhotoShot? shot;

  @override
  State<_ShotDialog> createState() => _ShotDialogState();
}

class _ShotDialogState extends State<_ShotDialog> {
  static const _uuid = Uuid();
  late final _label = TextEditingController(text: widget.shot?.label ?? '');
  late final _hint = TextEditingController(text: widget.shot?.hint ?? '');
  late bool _required = widget.shot?.required ?? false;

  @override
  void dispose() {
    _label.dispose();
    _hint.dispose();
    super.dispose();
  }

  void _submit() {
    final label = _label.text.trim();
    if (label.isEmpty) return;
    Navigator.of(context).pop(
      VehiclePhotoShot(
        key: widget.shot?.key ?? _uuid.v4(),
        label: label,
        hint: _hint.text.trim(),
        required: _required,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.shot == null ? 'Add a shot' : 'Edit shot'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _label,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What to photograph',
              hintText: 'e.g. Tires',
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _hint,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Hint (optional)',
              hintText: 'e.g. all four, close up',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Required to complete'),
            value: _required,
            onChanged: (v) => setState(() => _required = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
