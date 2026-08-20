import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entities/entity_link.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/schedule/widgets/trip_headcount_section.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/viewer_x.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/collapsible_section.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/trips/:blockId` — the field-trip setup + run-day surface.
///
/// Reached from BlockEditScreen when the kid sets `kind = field_trip`.
/// `trip_logistics` is 1:1 with the block.
///
/// The screen has two moments, and the layout honors both instead of
/// dumping everything at once (the "too much info, all in one" fix):
///   - Before setup (no row): just the basics form — destination,
///     address, notes. One clean task.
///   - After setup (row exists): lead with the trip's identity and a
///     single readiness line ("can we go?"), tuck the basics form behind
///     an "Edit trip basics" disclosure, and put the run-day sections —
///     headcount, permission slips, vehicles — into collapsible cards
///     that show a glanceable summary and open one tap away. Headcount
///     stays open by default (safety-first); the rest collapse.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({required this.blockId, super.key});

  /// schedule_blocks.id of the parent block. trip_logistics is
  /// 1:1 with the block.
  final String blockId;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  final _destination = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  TripLogistic? _existing;

  @override
  void dispose() {
    _destination.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Seed the form controllers from the latest row — deferred to after the
  /// frame so we never mutate a TextEditingController during build (the
  /// StreamBuilder rebuilds on every stream emission).
  void _scheduleSeed(TripLogistic? row) {
    if (_existing?.id == row?.id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _seed(row);
    });
  }

  void _seed(TripLogistic? row) {
    if (_existing?.id == row?.id) return;
    _existing = row;
    _destination.text = row?.destination ?? '';
    _address.text = row?.destinationAddress ?? '';
    _notes.text = row?.notes ?? '';
    _seededSnapshot = _snapshot();
  }

  /// Dirty = the typed fields differ from what the last seed wrote —
  /// back must not silently discard field-trip typing (the form law).
  String _seededSnapshot = '';
  String _snapshot() =>
      [_destination.text, _address.text, _notes.text].join('\u0000');

  Future<void> _save() async {
    final viewer = ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'save trip details');
    setState(() => _saving = true);
    try {
      final db = await ref.read(appDatabaseProvider.future);
      if (_existing == null) {
        await db.tripsDao.createLogistics(
          spaceId: spaceId,
          scheduleBlockId: widget.blockId,
          destination: _destination.text.trim(),
          destinationAddress: _address.text.trim().isEmpty
              ? null
              : _address.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await (db.update(
          db.tripLogistics,
        )..where((t) => t.id.equals(_existing!.id))).write(
          TripLogisticsCompanion(
            destination: Value(_destination.text.trim()),
            destinationAddress: Value(
              _address.text.trim().isEmpty ? null : _address.text.trim(),
            ),
            notes: Value(
              _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ),
            updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
          ),
        );
      }
      if (!mounted) return;
      // Reset the dirty baseline — the stream re-seed early-returns for the
      // same row id, so without this an edit-save still reads dirty and back
      // pops a spurious "Discard changes?" (Preflight 2026-07-13).
      setState(() => _seededSnapshot = _snapshot());
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Trip details saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dbAsync = ref.watch(appDatabaseProvider);
    return DismissGuard(
      isDirty: () => _snapshot() != _seededSnapshot,
      child: EdgeScaffold(
        backFallbackRoute: '/schedule',
        body: dbAsync.when(
          loading: () => const LoadingSlot(),
          error: (e, _) => ErrorState(
            title: 'Could not load trip details',
            onRetry: () => ref.invalidate(appDatabaseProvider),
          ),
          data: (db) {
            return StreamBuilder<TripLogistic?>(
              stream: db.tripsDao.watchByBlockId(widget.blockId),
              builder: (context, snap) {
                final row = snap.data;
                _scheduleSeed(row);
                // designed-empty: no logistics row yet IS a designed state —
                // the setup view invites the first fill-in.
                return row == null
                    ? _setupView(context)
                    : _glanceView(context, db, row);
              },
            );
          },
        ),
      ),
    );
  }

  /// No trip yet — a single, clean setup task.
  Widget _setupView(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        const ContentHeader(
          title: 'Plan this trip',
          subtitle:
              'Set the destination to get started — slips, vehicles, '
              'and headcount appear once the trip exists.',
        ),
        const SizedBox(height: 12),
        _formFields(context),
      ],
    );
  }

  /// Trip exists — identity + readiness up top, basics tucked away, the
  /// run-day sections collapsed one tap away.
  Widget _glanceView(BuildContext context, AppDatabase db, TripLogistic row) {
    final subjects =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];
    final requiresSlip = row.requiresPermissionSlip == 1;

    return StreamBuilder<List<PermissionSlip>>(
      stream: db.tripsDao.watchSlipsForTrip(row.id),
      builder: (context, slipSnap) {
        final slips = slipSnap.data ?? const <PermissionSlip>[];
        final signedIds = {for (final s in slips) s.subjectId};
        final total = subjects.length;
        final signedCount = subjects
            .where((s) => signedIds.contains(s.id))
            .length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _TripIdentity(row: row),
            const SizedBox(height: 14),
            CollapsibleSection(
              title: 'Edit trip basics',
              icon: Icons.edit_outlined,
              initiallyExpanded: false,
              headerPadding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _formFields(context),
              ),
            ),
            const SizedBox(height: 16),
            if (requiresSlip && total > 0) ...[
              _ReadinessBanner(signed: signedCount, total: total),
              const SizedBox(height: 16),
            ],
            // Safety-first: the roll-call leads, open by default.
            CollapsibleSection(
              key: const ValueKey('trip-headcount'),
              title: 'Headcount',
              icon: Icons.groups_outlined,
              headerPadding: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TripHeadcountSection(
                  blockId: widget.blockId,
                  groupId: null,
                  destination: row.destination,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (requiresSlip)
              CollapsibleSection(
                key: const ValueKey('trip-slips'),
                title: 'Permission slips',
                icon: Icons.assignment_turned_in_outlined,
                initiallyExpanded: false,
                headerPadding: EdgeInsets.zero,
                collapsedSummary: total == 0
                    ? 'no roster yet'
                    : '$signedCount / $total signed',
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _SlipList(
                    tripLogisticsId: row.id,
                    subjects: subjects,
                    signedIds: signedIds,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _VehiclesCollapsible(
              key: const ValueKey('trip-vehicles'),
              tripLogisticsId: row.id,
            ),
          ],
        );
      },
    );
  }

  /// The destination / address / notes fields + save. Shared by the
  /// setup view and the "Edit trip basics" disclosure.
  Widget _formFields(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _destination,
          decoration: const InputDecoration(
            labelText: 'Destination',
            hintText: 'Pumpkin patch · Aquarium',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          decoration: const InputDecoration(
            labelText: 'Address (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'Pack lunch · sunscreen · meet at lobby',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('Save trip details'),
        ),
      ],
    );
  }
}

/// The trip's identity — a "field trip" chip, the destination as the
/// headline (serif display), and the address + times when present.
class _TripIdentity extends StatelessWidget {
  const _TripIdentity({required this.row});

  final TripLogistic row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final dep = row.departureAt == null
        ? null
        : DateTime.tryParse(row.departureAt!)?.toLocal();
    final ret = row.returnAt == null
        ? null
        : DateTime.tryParse(row.returnAt!)?.toLocal();
    final timeStr = dep == null
        ? null
        : 'Departs ${timeOfDay(dep)}'
              '${ret != null ? ' · back ${timeOfDay(ret)}' : ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.directions_bus_outlined,
                size: 14,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                'Field trip',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          row.destination.isEmpty ? 'Untitled trip' : row.destination,
          style: theme.textTheme.headlineSmall,
        ),
        if (row.destinationAddress != null &&
            row.destinationAddress!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          _MetaLine(icon: Icons.place_outlined, text: row.destinationAddress!),
        ],
        if (timeStr != null) ...[
          const SizedBox(height: 2),
          _MetaLine(icon: Icons.schedule_outlined, text: timeStr),
        ],
      ],
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one-line "can we go?" answer, driven by slip completion.
class _ReadinessBanner extends StatelessWidget {
  const _ReadinessBanner({required this.signed, required this.total});

  final int signed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = signed >= total;
    final bg = ready ? scheme.primaryContainer : scheme.tertiaryContainer;
    final fg = ready ? scheme.onPrimaryContainer : scheme.onTertiaryContainer;
    final remaining = total - signed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.check_circle_outline : Icons.error_outline,
            size: 20,
            color: fg,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ready ? 'Ready to go' : 'Almost ready',
                  style: theme.textTheme.titleSmall?.copyWith(color: fg),
                ),
                const SizedBox(height: 1),
                Text(
                  ready
                      ? 'All $total slips are in.'
                      : 'Collect $remaining more '
                            '${remaining == 1 ? 'slip' : 'slips'} before you go.',
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The per-kid slip list — unsigned kids first (the ones needing action),
/// tap an unsigned kid to mark their slip received.
class _SlipList extends ConsumerStatefulWidget {
  const _SlipList({
    required this.tripLogisticsId,
    required this.subjects,
    required this.signedIds,
  });

  final String tripLogisticsId;
  final List<Subject> subjects;
  final Set<String> signedIds;

  @override
  ConsumerState<_SlipList> createState() => _SlipListState();
}

class _SlipListState extends ConsumerState<_SlipList> {
  /// Subjects whose slip write is in flight — guards a double-tap from
  /// firing two `recordSlip` inserts before the stream propagates the
  /// first one back into `signedIds`.
  final _pending = <String>{};

  Future<void> _mark(String subjectId) async {
    if (widget.signedIds.contains(subjectId) || _pending.contains(subjectId)) {
      return;
    }
    final viewer = ref.read(viewerProvider);
    final spaceId = viewer.requireSpaceId(action: 'record slip');
    setState(() => _pending.add(subjectId));
    try {
      final db = await ref.read(appDatabaseProvider.future);
      await db.tripsDao.recordSlip(
        spaceId: spaceId,
        tripLogisticsId: widget.tripLogisticsId,
        subjectId: subjectId,
        signerName: 'In-person',
      );
    } finally {
      if (mounted) setState(() => _pending.remove(subjectId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = widget.subjects;
    if (subjects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No kids in your roster yet.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Unsigned first — the actionable kids rise to the top.
    final ordered = [...subjects]
      ..sort((a, b) {
        final aSigned = widget.signedIds.contains(a.id) ? 1 : 0;
        final bSigned = widget.signedIds.contains(b.id) ? 1 : 0;
        if (aSigned != bSigned) return aSigned - bSigned;
        return a.firstName.compareTo(b.firstName);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final subj in ordered) _tile(theme, subj)],
    );
  }

  Widget _tile(ThemeData theme, Subject subj) {
    final signed = widget.signedIds.contains(subj.id);
    final pending = _pending.contains(subj.id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: pending
          ? const SizedBox(
              width: 24,
              height: 24,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Icon(
              signed
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
              color: signed
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
      title: EntityLink(
        entity: EntityRef(
          kind: EntityKind.subject,
          id: subj.id,
          label: '${subj.firstName} ${subj.lastName}',
        ),
        padded: false,
        style: theme.textTheme.titleMedium,
      ),
      trailing: signed
          ? null
          : Text(
              'Mark received',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
      onTap: signed ? null : () => _mark(subj.id),
    );
  }
}

/// Vehicles + drivers, collapsed with an "N assigned" summary.
class _VehiclesCollapsible extends ConsumerWidget {
  const _VehiclesCollapsible({required this.tripLogisticsId, super.key});

  final String tripLogisticsId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dbAsync = ref.watch(appDatabaseProvider);
    if (dbAsync.value == null) return const SizedBox.shrink();
    final db = dbAsync.value!;

    return StreamBuilder<List<TripVehicle>>(
      stream: db.tripsDao.watchVehiclesFor(tripLogisticsId),
      builder: (context, snap) {
        final vehicles = snap.data ?? const <TripVehicle>[];
        return CollapsibleSection(
          title: 'Vehicles & drivers',
          icon: Icons.directions_bus_filled_outlined,
          initiallyExpanded: false,
          headerPadding: EdgeInsets.zero,
          collapsedSummary: vehicles.isEmpty
              ? 'none yet'
              : '${vehicles.length} assigned',
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: vehicles.isEmpty
                ? Text(
                    'No vehicles assigned. Assign from the Vehicles screen '
                    "once the trip's destination is set.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final v in vehicles)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.directions_bus_outlined),
                          title: Text('Vehicle ${v.vehicleId.substring(0, 6)}'),
                          subtitle: Text(
                            v.driverMemberId == null
                                ? 'No driver assigned'
                                : 'Driver: ${v.driverMemberId!.substring(0, 6)}',
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
