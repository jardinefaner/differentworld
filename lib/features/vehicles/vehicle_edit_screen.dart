import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/settings/vehicles/new` and `/settings/vehicles/:id/edit`.
///
/// Director-only. Per `docs/UX_DECISIONS.md §2`, vehicle settings are
/// a routable screen (not a sheet) because they're persistent state
/// the user comes back to.
class VehicleEditScreen extends ConsumerStatefulWidget {
  const VehicleEditScreen({this.vehicleId, super.key});

  final String? vehicleId;

  bool get isEdit => vehicleId != null;

  @override
  ConsumerState<VehicleEditScreen> createState() =>
      _VehicleEditScreenState();
}

class _VehicleEditScreenState extends ConsumerState<VehicleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  final _color = TextEditingController();
  final _notes = TextEditingController();

  bool _saving = false;
  String? _error;
  bool _seeded = false;

  @override
  void dispose() {
    _name.dispose();
    _make.dispose();
    _model.dispose();
    _year.dispose();
    _plate.dispose();
    _color.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _seedFromVehicle(Vehicle? v) {
    if (_seeded || v == null) return;
    _name.text = v.name;
    _make.text = v.make ?? '';
    _model.text = v.model ?? '';
    _year.text = v.year?.toString() ?? '';
    _plate.text = v.licensePlate ?? '';
    _color.text = v.color ?? '';
    _notes.text = v.notes ?? '';
    _seeded = true;
  }

  bool _isDirty(Vehicle? v) {
    if (v == null) {
      return _name.text.trim().isNotEmpty ||
          _make.text.trim().isNotEmpty ||
          _model.text.trim().isNotEmpty ||
          _year.text.trim().isNotEmpty ||
          _plate.text.trim().isNotEmpty ||
          _color.text.trim().isNotEmpty ||
          _notes.text.trim().isNotEmpty;
    }
    return _name.text.trim() != v.name ||
        _make.text.trim() != (v.make ?? '') ||
        _model.text.trim() != (v.model ?? '') ||
        _year.text.trim() != (v.year?.toString() ?? '') ||
        _plate.text.trim() != (v.licensePlate ?? '') ||
        _color.text.trim() != (v.color ?? '') ||
        _notes.text.trim() != (v.notes ?? '');
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final actions = ref.read(vehicleActionsProvider);
      final name = _name.text.trim();
      final make = _emptyToNull(_make.text);
      final model = _emptyToNull(_model.text);
      final year = int.tryParse(_year.text.trim());
      final plate = _emptyToNull(_plate.text)?.toUpperCase();
      final color = _emptyToNull(_color.text);
      final notes = _emptyToNull(_notes.text);

      if (widget.isEdit) {
        await actions.update(
          id: widget.vehicleId!,
          name: name,
          make: make ?? '',
          model: model ?? '',
          year: year,
          licensePlate: plate ?? '',
          color: color ?? '',
          notes: notes ?? '',
        );
      } else {
        await actions.create(
          name: name,
          make: make,
          model: model,
          year: year,
          licensePlate: plate,
          color: color,
          notes: notes,
        );
      }
      if (!mounted) return;
      context.pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'vehicles'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!widget.isEdit) return;
    if (!ref.read(viewerProvider).canManageSpace) return;
    final v = ref.read(vehicleByIdProvider(widget.vehicleId!)).value;
    if (v == null) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete ${v.name}?',
      message:
          'The vehicle and its entire check-in / check-out history will '
          'be removed. This cannot be undone.',
      confirmLabel: 'Delete vehicle',
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(vehicleActionsProvider).delete(v.id);
      if (!mounted) return;
      context.pop();
      if (!mounted) return;
      if (context.canPop()) context.pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'vehicles'),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not delete. Please try again.';
      });
    }
  }

  String? _emptyToNull(String input) {
    final t = input.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    if (!viewer.canManageSpace) {
      return const EdgeScaffold(
        backFallbackRoute: '/settings/vehicles',
        body: NoAccess(
          title: 'Only directors can edit vehicles.',
          message: 'Ask the program director to make changes.',
        ),
      );
    }

    final theme = Theme.of(context);
    final vehicleAsync = widget.isEdit
        ? ref.watch(vehicleByIdProvider(widget.vehicleId!))
        : const AsyncValue<Vehicle?>.data(null);
    final vehicleForDirty =
        (vehicleAsync..whenData(_seedFromVehicle)).value;

    return DismissGuard(
      isDirty: () => _isDirty(vehicleForDirty),
      child: EdgeScaffold(
        backFallbackRoute: widget.isEdit
            ? '/settings/vehicles/${widget.vehicleId}'
            : '/settings/vehicles',
        body: vehicleAsync.when(
          loading: () => const LoadingSlot(),
          error: (_, _) => const ErrorState(title: 'Could not load vehicle'),
          data: (v) {
            if (widget.isEdit && v == null) {
              return const EmptyState(
                icon: Icons.directions_car_outlined,
                title: 'Vehicle not found',
              );
            }
            return Stack(
              children: [
                FormBody(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                ContentHeader(
                  title: widget.isEdit ? 'Edit vehicle' : 'New vehicle',
                  subtitle: widget.isEdit
                      ? null
                      : 'Add a vehicle for drivers to check out',
                ),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _name,
                        autofocus: !widget.isEdit,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Vehicle name',
                          hintText: 'e.g. Big Green Van',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final t = value?.trim() ?? '';
                          if (t.isEmpty) return 'Required';
                          if (t.length < 2) return 'Too short';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _make,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Make',
                                hintText: 'Ford',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _model,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Model',
                                hintText: 'Transit 350',
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
                              controller: _year,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Year',
                                hintText: '2023',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final t = value?.trim() ?? '';
                                if (t.isEmpty) return null;
                                final n = int.tryParse(t);
                                if (n == null) return 'Numbers only';
                                if (n < 1990 || n > 2100) {
                                  return 'Out of range';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _color,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Color',
                                hintText: 'Green',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _plate,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'License plate',
                          hintText: '03234E4',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notes,
                        minLines: 2,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          hintText:
                              'Insurance contact, fuel card #, quirks…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
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
                if (widget.isEdit) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DestructiveButton(
                      label: 'Delete vehicle',
                      onPressed: _saving ? null : _delete,
                    ),
                  ),
                ],
                const SizedBox(height: 88), // clearance for sticky bar
              ],
            ),
            // Bottom-sticky save bar: always reachable on long forms.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  color: theme.colorScheme.surface,
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
                        widget.isEdit ? 'Save changes' : 'Create vehicle',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
