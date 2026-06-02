import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/vehicles/guided_capture_screen.dart';
import 'package:differentworld/features/vehicles/inspection_checklist.dart';
import 'package:differentworld/features/vehicles/vehicle_photo_shots.dart';
import 'package:differentworld/features/vehicles/vehicle_roster.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
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
import 'package:uuid/uuid.dart';

/// The FACES-style pre/post-trip inspection. Same screen for both
/// `kind` values — the only differences are the screen title and
/// the submit button label.
///
/// Routes:
///   /vehicles/:id/checkout
///   /vehicles/:id/checkin
class VehicleInspectionScreen extends ConsumerStatefulWidget {
  const VehicleInspectionScreen({
    required this.vehicleId,
    required this.kind,
    super.key,
  });

  final String vehicleId;
  final String kind; // VehicleLogKind.checkout | VehicleLogKind.checkin

  bool get isCheckout => kind == VehicleLogKind.checkout;

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

  /// Guided-capture photos taken for this inspection (ordered by shot).
  final List<CapturedShot> _captures = [];

  // Make submit RESUMABLE so a mid-upload failure + retry doesn't create a
  // second log or duplicate attachments: the log is created once
  // (_pendingLogId), and each photo is attached once (_attachedKeys).
  String? _pendingLogId;
  final Set<String> _attachedKeys = {};

  // Roster headcount (docs/VISION.md vehicle safety ritual). Check-out: the
  // driver picks who boards (_boardedIds). Check-in: _boardedIds is seeded
  // from the open check-out's roster, and _offIds tracks who's been tapped
  // off; complete is blocked until everyone's off (_boardedIds ⊆ _offIds).
  final Set<String> _boardedIds = {};
  final Set<String> _offIds = {};
  bool _rosterSeeded = false;

  bool _saving = false;
  String? _error;

  Set<String> get _stillOnBoard => _boardedIds.difference(_offIds);

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
        _captures.isNotEmpty ||
        // Check-out: boarding picks are a change. Check-in: only tap-offs
        // are (the boarded list is seeded from the open check-out, not typed).
        (widget.isCheckout ? _boardedIds.isNotEmpty : _offIds.isNotEmpty) ||
        _results.toJson() != '{}';
  }

  Future<void> _submit(String capabilitiesJson) async {
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

    // Gate on the required photos — the empty-cabin check-in shot is the
    // one this whole feature exists for (vehicle_photo_shots.dart).
    final shots = shotsFor(capabilitiesJson, widget.kind);
    final missing = shots
        .where((s) => s.required && !_captures.any((c) => c.key == s.key))
        .toList();
    if (missing.isNotEmpty) {
      setState(() => _error =
          'Take the required photos first: '
          '${missing.map((s) => s.label).join(', ')}.');
      return;
    }

    // Headcount gate (check-in): every child who boarded must be tapped off.
    // The act that prevents leaving a child — pairs with the empty-cabin photo.
    if (!widget.isCheckout &&
        _boardedIds.isNotEmpty &&
        !headcountCleared(_boardedIds, _offIds)) {
      setState(() => _error =
          'Confirm every child is out — ${_stillOnBoard.length} still on board.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final actions = ref.read(vehicleLogActionsProvider);
      // Create the log ONCE — reused across retries so a failed photo
      // upload can't spawn a duplicate check-in/out row.
      final logId = _pendingLogId ??= await actions.log(
        vehicleId: widget.vehicleId,
        kind: widget.kind,
        odometer: int.tryParse(_odometer.text.trim()),
        fuelLevel: _emptyToNull(_fuelLevel.text),
        itemsJson: _results.toJson(),
        notes: _emptyToNull(_notes.text),
        bodyDamageNotes: _emptyToNull(_bodyDamage.text),
        // Record the trip's occupancy on both logs (check-out: who boarded;
        // check-in: the same list, all confirmed off by the gate above).
        roster: jsonEncode(_boardedIds.toList()),
      );
      // Attach each photo once. Upload the bytes (online → Storage path;
      // offline → queued, returns a pending token), then create the
      // attachment with the SAME id so a deferred upload's queue-side
      // updateUrl(id) patches THIS row — no silent loss of a safety photo.
      // _attachedKeys makes a retry resume where it failed (no duplicates).
      final photoService = ref.read(photoServiceProvider);
      final attachments = ref.read(attachmentActionsProvider);
      for (var i = 0; i < _captures.length; i++) {
        final cap = _captures[i];
        if (_attachedKeys.contains(cap.key)) continue;
        final attId = const Uuid().v4();
        final url = await photoService.uploadOnly(
          entityKind: 'attachment',
          entityId: attId,
          picked: cap.file,
        );
        await attachments.add(
          id: attId,
          entityKind: 'vehicle_log',
          entityId: logId,
          url: url,
          caption: cap.label,
          sortOrder: i,
        );
        _attachedKeys.add(cap.key);
      }
      if (!mounted) return;
      context.pop();
    } on Object catch (e, st) {
      // on Object (not Exception) — uploadOnly / attachments.add can throw a
      // StateError (no Space), which is an Error, not an Exception.
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'vehicles'),
      );
      if (!mounted) return;
      setState(() => _error = "Couldn't save. Please try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Launch the guided camera for this kind's shot list, storing the result.
  Future<void> _takePhotos(String capabilitiesJson) async {
    final shots = shotsFor(capabilitiesJson, widget.kind);
    final result = await Navigator.of(context).push<List<CapturedShot>>(
      MaterialPageRoute(
        builder: (_) => GuidedCaptureScreen(
          shots: shots,
          title: widget.isCheckout ? 'Check-out photos' : 'Check-in photos',
        ),
        fullscreenDialog: true,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _captures
          ..clear()
          ..addAll(result);
      });
    }
  }

  Widget _photosCard(String capabilitiesJson) {
    final theme = Theme.of(context);
    final shots = shotsFor(capabilitiesJson, widget.kind);
    final requiredShots = shots.where((s) => s.required).toList();
    final capturedKeys = _captures.map((c) => c.key).toSet();
    final missing =
        requiredShots.where((s) => !capturedKeys.contains(s.key)).toList();
    final taken = _captures.length;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.photo_camera_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Required photos', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (taken > 0)
                  Text(
                    '$taken of ${shots.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              missing.isEmpty
                  ? (taken > 0
                        ? 'Required photos captured.'
                        : 'Walk the guided camera to capture the required photos.')
                  : 'Still needed: ${missing.map((s) => s.label).join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: missing.isEmpty
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
            if (_captures.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _captures.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _captures[i].bytes,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, _, _) =>
                          const SizedBox(width: 64, height: 64),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _takePhotos(capabilitiesJson),
                icon: Icon(
                  taken > 0
                      ? Icons.replay_outlined
                      : Icons.photo_camera_outlined,
                ),
                label: Text(taken > 0 ? 'Review / retake' : 'Take photos'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Seed the check-in tap-off list from the open check-out's roster (once).
  void _seedRosterIfNeeded(AsyncValue<VehicleLog?> latest) {
    if (_rosterSeeded || widget.isCheckout) return;
    // Wait for the provider to RESOLVE. On cold launch the first build sees
    // AsyncLoading (value == null); marking seeded then would lock in an
    // EMPTY roster, and the check-in gate (`_boardedIds.isNotEmpty && …`)
    // would vacuously pass — a child could be left on board. Only seed once
    // the real log has loaded. (Preflight BLOCKER, 2026-06-02.)
    if (!latest.hasValue) return;
    _rosterSeeded = true;
    final log = latest.value;
    if (log != null && log.kind == VehicleLogKind.checkout) {
      _boardedIds.addAll(parseRoster(log.roster));
    }
  }

  /// Check-out: pick who boards. Check-in: tap each boarded child off; the
  /// submit gate blocks until everyone's off (paired with the empty-cabin
  /// photo — the actual hot-car prevention).
  Widget _rosterCard() {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    final nameById = {for (final s in subjects) s.id: s.firstName};

    if (widget.isCheckout) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.groups_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text("Who's on board?", style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    _boardedIds.isEmpty ? 'Optional' : '${_boardedIds.length} boarding',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (subjects.isEmpty)
                Text(
                  'No children in the roster yet.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in subjects)
                      FilterChip(
                        label: Text(s.firstName),
                        selected: _boardedIds.contains(s.id),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _boardedIds.add(s.id);
                          } else {
                            _boardedIds.remove(s.id);
                          }
                        }),
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    // Check-in.
    if (_boardedIds.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No boarding record for this trip — confirm the cabin is '
                  'empty with the photo.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final stillOn = _stillOnBoard;
    final allOut = stillOn.isEmpty;
    return Card(
      margin: EdgeInsets.zero,
      color: allOut ? null : theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allOut ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: allOut ? Colors.green : theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text('Everyone out?', style: theme.textTheme.titleMedium),
                const Spacer(),
                Text(
                  allOut
                      ? 'All out ✓'
                      : '${stillOn.length} of ${_boardedIds.length} still on board',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: allOut ? Colors.green : theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Tap each child as they step off.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final id in _boardedIds)
                  FilterChip(
                    label: Text(nameById[id] ?? 'Child'),
                    selected: _offIds.contains(id),
                    avatar: _offIds.contains(id)
                        ? const Icon(Icons.check, size: 18)
                        : null,
                    onSelected: (off) => setState(() {
                      if (off) {
                        _offIds.add(id);
                      } else {
                        _offIds.remove(id);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _markAllOk() {
    setState(() {
      for (final item in InspectionChecklist.items) {
        _results.setStatus(item, InspectionStatus.ok);
      }
    });
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
        backFallbackRoute: '/vehicles/${widget.vehicleId}',
        body: const NoAccess(
          title: 'Driver certification required',
          message:
              'Only members with the Driver certification can check '
              'a vehicle in or out.',
        ),
      );
    }

    final vehicleAsync = ref.watch(vehicleByIdProvider(widget.vehicleId));
    // Check-in seeds the tap-off list from the open check-out's roster (only
    // once the provider has RESOLVED — see _seedRosterIfNeeded).
    _seedRosterIfNeeded(ref.watch(latestVehicleLogProvider(widget.vehicleId)));

    return DismissGuard(
      isDirty: _isDirty,
      child: EdgeScaffold(
        backFallbackRoute: '/vehicles/${widget.vehicleId}',
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
            // The "Unsafe" status anywhere in the checklist surfaces a
            // confirm banner above the bottom submit; the driver can
            // still complete (the incident gets logged with the row)
            // but the urgency is hard to miss.
            final hasUnsafe = InspectionChecklist.items.any(
              (item) =>
                  _results.statusFor(item) == InspectionStatus.unsafe,
            );
            return Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: FormBody(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      children: [
                        ContentHeader(
                          title:
                              widget.isCheckout ? 'Check out' : 'Check in',
                          subtitle: widget.isCheckout
                              ? '${v.name} · pre-trip safety check'
                              : '${v.name} · post-trip safety check',
                          bottomGap: 12,
                        ),
                        // Photos FIRST — capture the required shots at the
                        // vehicle (the empty-cabin sweep the moment you park)
                        // before the checklist (docs/VISION.md vehicle ritual).
                        _photosCard(v.capabilities),
                        const SizedBox(height: 16),
                        _rosterCard(),
                        const SizedBox(height: 16),
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
                                textCapitalization:
                                    TextCapitalization.characters,
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
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Inspection checklist',
                                style: theme.textTheme.titleMedium,
                              ),
                              const Spacer(),
                              // Real pre-trip checks are mostly all-good — one
                              // tap marks every item OK, then flag exceptions.
                              TextButton.icon(
                                onPressed: _markAllOk,
                                icon: const Icon(Icons.done_all, size: 18),
                                label: const Text('Mark all OK'),
                              ),
                            ],
                          ),
                        ),
                        // One card per section. Each card carries its
                        // own progress count so the driver can pace
                        // through ("Lights 4/4 · Tires 1/2 …").
                        for (final section in InspectionChecklist.sections)
                          _SectionCard(
                            label:
                                InspectionChecklist.sectionLabels[section] ??
                                    section,
                            items:
                                InspectionChecklist.itemsForSection(section),
                            results: _results,
                            onChanged: (item, st) {
                              setState(() => _results.setStatus(item, st));
                            },
                          ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bodyDamage,
                          minLines: 2,
                          maxLines: 3,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Body damage (optional)',
                            hintText:
                                'Describe any scratches, dents, etc.',
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
                      ],
                    ),
                  ),
                ),
                if (hasUnsafe)
                  Container(
                    width: double.infinity,
                    color: theme.colorScheme.errorContainer,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.dangerous_outlined,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You marked at least one item Unsafe. '
                            'The director will be notified after you '
                            'complete this report.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Bottom-sticky submit: always reachable while
                // scrolling the checklist. Mirrors the M3 BottomAppBar
                // pattern but lighter.
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _submit(v.capabilities),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(widget.isCheckout
                                ? Icons.key_outlined
                                : Icons.assignment_turned_in_outlined),
                        label: Text(
                          widget.isCheckout
                              ? 'Complete check-out'
                              : 'Complete check-in',
                        ),
                        style: FilledButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.label,
    required this.items,
    required this.results,
    required this.onChanged,
  });

  final String label;
  final List<InspectionItem> items;
  final InspectionResults results;
  final void Function(InspectionItem item, InspectionStatus? next) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final marked =
        items.where((i) => results.statusFor(i) != null).length;
    final total = items.length;
    final hasUnsafe = items.any(
      (i) => results.statusFor(i) == InspectionStatus.unsafe,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasUnsafe
                ? scheme.error.withValues(alpha: 0.6)
                : scheme.outlineVariant,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: theme.textTheme.titleSmall),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: marked == total
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$marked / $total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: marked == total
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final item in items)
              _InspectionRow(
                item: item,
                status: results.statusFor(item),
                onChanged: (s) => onChanged(item, s),
              ),
          ],
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
        borderRadius: BorderRadius.circular(8),
        // 48×48 hit target is the M3 floor for accessibility. The
        // visual chip sits inside a transparent border the user can't
        // see but the hit region honours.
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: fg, size: 20),
          ),
        ),
      ),
    );
  }
}
