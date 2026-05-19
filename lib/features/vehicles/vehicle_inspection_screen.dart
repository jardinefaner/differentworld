import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/vehicles/inspection_checklist.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The FACES-style pre/post-trip inspection. Same screen for both
/// `kind` values — the only differences are the screen title and
/// the submit button label.
///
/// Routes:
///   /settings/vehicles/:id/checkout
///   /settings/vehicles/:id/checkin
class VehicleInspectionScreen extends ConsumerStatefulWidget {
  const VehicleInspectionScreen({
    required this.vehicleId,
    required this.kind,
    super.key,
  });

  final String vehicleId;
  final String kind; // 'checkout' | 'checkin'

  bool get isCheckout => kind == 'checkout';

  @override
  ConsumerState<VehicleInspectionScreen> createState() =>
      _VehicleInspectionScreenState();
}

class _VehicleInspectionScreenState
    extends ConsumerState<VehicleInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometer = TextEditingController();
  final _fuelLevel = TextEditingController();
  final _notes = TextEditingController();
  final _bodyDamage = TextEditingController();

  late InspectionResults _results;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _results = InspectionResults();
  }

  @override
  void dispose() {
    _odometer.dispose();
    _fuelLevel.dispose();
    _notes.dispose();
    _bodyDamage.dispose();
    super.dispose();
  }

  bool _isDirty() {
    return _odometer.text.trim().isNotEmpty ||
        _fuelLevel.text.trim().isNotEmpty ||
        _notes.text.trim().isNotEmpty ||
        _bodyDamage.text.trim().isNotEmpty ||
        _results.toJson() != '{}';
  }

  Future<void> _submit() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    if (!_results.isComplete) {
      setState(() => _error =
          'Mark every item — OK, Needs repair, or Unsafe.');
      // Soft-scroll-friendly: also focus the first unset item visually
      // would be nice; for v1 the inline message is enough.
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final actions = ref.read(vehicleLogActionsProvider);
      await actions.log(
        vehicleId: widget.vehicleId,
        kind: widget.kind,
        odometer: int.tryParse(_odometer.text.trim()),
        fuelLevel: _emptyToNull(_fuelLevel.text),
        itemsJson: _results.toJson(),
        notes: _emptyToNull(_notes.text),
        bodyDamageNotes: _emptyToNull(_bodyDamage.text),
      );
      if (!mounted) return;
      context.pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'vehicles'),
      );
      if (!mounted) return;
      setState(() => _error = "Couldn't save. Please try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String input) {
    final t = input.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);

    // Defence-in-depth — UI gates the entry point on canDrive too.
    if (!viewer.canDrive) {
      return EdgeScaffold(
        backFallbackRoute: '/settings/vehicles/${widget.vehicleId}',
        body: const NoAccess(
          title: 'Driver certification required',
          message:
              'Only members with the Driver certification can check '
              'a vehicle in or out.',
        ),
      );
    }

    final vehicleAsync = ref.watch(vehicleByIdProvider(widget.vehicleId));

    return DismissGuard(
      isDirty: _isDirty,
      child: EdgeScaffold(
        backFallbackRoute: '/settings/vehicles/${widget.vehicleId}',
        actions: [
          IconButton(
            tooltip: widget.isCheckout ? 'Check out' : 'Check in',
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
        body: vehicleAsync.when(
          loading: () => const LoadingSlot(),
          error: (_, _) =>
              const Center(child: Text('Could not load vehicle.')),
          data: (v) {
            if (v == null) {
              return const Center(child: Text('Vehicle not found.'));
            }
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 56, 16, 32),
                children: [
                  ContentHeader(
                    title: widget.isCheckout ? 'Check out' : 'Check in',
                    subtitle: '${v.name} · pre-trip safety check',
                  ),
                  // Trip header — odometer + fuel
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _odometer,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(7),
                          ],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Odometer',
                            suffixText: 'mi',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final t = value?.trim() ?? '';
                            if (t.isEmpty) return 'Required';
                            final n = int.tryParse(t);
                            if (n == null) return 'Numbers only';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fuelLevel,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Fuel level',
                            hintText: '3/4, F, 1/2 tank',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Inspection checklist
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Inspection checklist',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mark each item OK, Needs repair, or Unsafe.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final section in InspectionChecklist.sections) ...[
                          const SizedBox(height: 4),
                          Text(
                            InspectionChecklist.sectionLabels[section] ??
                                section,
                            style: theme.textTheme.labelLarge,
                          ),
                          const SizedBox(height: 4),
                          for (final item
                              in InspectionChecklist.itemsForSection(section))
                            _InspectionRow(
                              item: item,
                              status: _results.statusFor(item),
                              onChanged: (s) {
                                setState(() => _results.setStatus(item, s));
                              },
                            ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bodyDamage,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Body damage (optional)',
                      hintText: 'Describe any scratches, dents, etc.',
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
                      border: OutlineInputBorder(),
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
                  const SizedBox(height: 16),
                  // Big submit button at the bottom too, mirroring the
                  // FACES form's design (action live at the end).
                  FilledButton.icon(
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(widget.isCheckout
                            ? Icons.key_outlined
                            : Icons.assignment_turned_in_outlined),
                    label: Text(
                      widget.isCheckout ? 'Complete check-out' : 'Complete check-in',
                    ),
                  ),
                  const SizedBox(height: 64),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Three-button segmented control for a single FACES item. Uses chips
/// rather than SegmentedButton so tapping never accidentally flips a
/// neighbor on small screens. The currently-selected status colors in;
/// unsafe gets the error tint to draw the eye.
class _InspectionRow extends StatelessWidget {
  const _InspectionRow({
    required this.item,
    required this.status,
    required this.onChanged,
  });

  final InspectionItem item;
  final InspectionStatus? status;
  final ValueChanged<InspectionStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, style: theme.textTheme.bodyMedium),
                if (item.subtitle != null)
                  Text(
                    item.subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          _StatusButton(
            icon: Icons.check,
            label: 'OK',
            color: theme.colorScheme.primary,
            selected: status == InspectionStatus.ok,
            onTap: () => onChanged(
              status == InspectionStatus.ok ? null : InspectionStatus.ok,
            ),
          ),
          const SizedBox(width: 4),
          _StatusButton(
            icon: Icons.handyman_outlined,
            label: 'Repair',
            color: theme.colorScheme.tertiary,
            selected: status == InspectionStatus.needsRepair,
            onTap: () => onChanged(
              status == InspectionStatus.needsRepair
                  ? null
                  : InspectionStatus.needsRepair,
            ),
          ),
          const SizedBox(width: 4),
          _StatusButton(
            icon: Icons.dangerous_outlined,
            label: 'Unsafe',
            color: theme.colorScheme.error,
            selected: status == InspectionStatus.unsafe,
            onTap: () => onChanged(
              status == InspectionStatus.unsafe
                  ? null
                  : InspectionStatus.unsafe,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? color : theme.colorScheme.surfaceContainerHighest;
    final fg = selected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: fg, size: 18),
        ),
      ),
    );
  }
}
