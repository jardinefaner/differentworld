import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/schedule/trip_headcount.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The headcount spine on a field trip — the safety roll-call for each leg
/// (departure → at destination → return). Each leg taps into a roll-call sheet
/// where every child is counted on; anyone unaccounted for blocks the confirm
/// behind a reason-required override. Data rides append-only `trip_headcount`
/// entries (no migration).
class TripHeadcountSection extends ConsumerWidget {
  const TripHeadcountSection({
    required this.blockId,
    required this.groupId,
    required this.destination,
    super.key,
  });

  final String blockId;
  final String? groupId;
  final String destination;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final legs = ref.watch(tripHeadcountsProvider(blockId));
    final roster =
        ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[];

    // The first not-yet-settled leg gets the prominent "Count now" CTA.
    final firstPending = TripLeg.ordered.firstWhere(
      (l) => !(legs[l]?.done ?? false),
      orElse: () => '',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Headcount', style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Count everyone on, at, and back. Anyone missing blocks the bus.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final leg in TripLeg.ordered)
          _LegRow(
            leg: leg,
            destination: destination,
            count: legs[leg],
            rosterSize: roster.length,
            emphasize: leg == firstPending,
            onTap: () => showTripRollCall(
              context,
              blockId: blockId,
              groupId: groupId,
              leg: leg,
              destination: destination,
              roster: roster,
              previous: legs[leg],
            ),
          ),
      ],
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({
    required this.leg,
    required this.destination,
    required this.count,
    required this.rosterSize,
    required this.emphasize,
    required this.onTap,
  });

  final String leg;
  final String destination;
  final TripHeadcountLeg? count;
  final int rosterSize;
  final bool emphasize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = count?.done ?? false;
    final overridden = (count?.overrideReason ?? '').isNotEmpty;
    final total = count?.expected ?? rosterSize;

    final Color dotBg;
    final Color dotFg;
    final IconData dotIcon;
    if (overridden) {
      dotBg = scheme.tertiary;
      dotFg = scheme.onTertiary;
      dotIcon = Icons.priority_high;
    } else if (done) {
      dotBg = scheme.primary;
      dotFg = scheme.onPrimary;
      dotIcon = Icons.check;
    } else {
      dotBg = scheme.surfaceContainerHighest;
      dotFg = scheme.onSurfaceVariant;
      dotIcon = Icons.groups_outlined;
    }

    return Semantics(
      button: true,
      label:
          '${TripLeg.label(leg)} headcount, '
          '${done ? "${count!.count} of $total counted" : "not counted yet"}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: dotBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(dotIcon, size: 17, color: dotFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        TripLeg.label(leg),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        overridden
                            ? 'Left with a reason on file'
                            : TripLeg.sublabel(leg, destination),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: overridden
                              ? scheme.tertiary
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (done)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${count!.count} / $total',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: overridden ? scheme.tertiary : scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (count!.takenAt != null)
                        Text(
                          DateFormat.jm().format(count!.takenAt!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: emphasize
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fact_check_outlined,
                          size: 15,
                          color: emphasize
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Count now',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: emphasize
                                ? scheme.onPrimary
                                : scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the roll-call sheet for one leg.
Future<void> showTripRollCall(
  BuildContext context, {
  required String blockId,
  required String? groupId,
  required String leg,
  required String destination,
  required List<Subject> roster,
  TripHeadcountLeg? previous,
}) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RollCallSheet(
      blockId: blockId,
      groupId: groupId,
      leg: leg,
      destination: destination,
      roster: roster,
      previous: previous,
    ),
  );
}

class _RollCallSheet extends ConsumerStatefulWidget {
  const _RollCallSheet({
    required this.blockId,
    required this.groupId,
    required this.leg,
    required this.destination,
    required this.roster,
    required this.previous,
  });

  final String blockId;
  final String? groupId;
  final String leg;
  final String destination;
  final List<Subject> roster;
  final TripHeadcountLeg? previous;

  @override
  ConsumerState<_RollCallSheet> createState() => _RollCallSheetState();
}

class _RollCallSheetState extends ConsumerState<_RollCallSheet> {
  late final Set<String> _present = {
    // Pre-check whoever was present at the previous count of THIS leg (a
    // re-count); a fresh leg starts empty so each kid is deliberately counted.
    ...?widget.previous?.present.where(
      (id) => widget.roster.any((s) => s.id == id),
    ),
  };
  bool _saving = false;

  int get _total => widget.roster.length;
  bool get _complete => _total > 0 && _present.length >= _total;

  List<Subject> get _missing =>
      widget.roster.where((s) => !_present.contains(s.id)).toList();

  void _toggle(String id) {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      if (!_present.remove(id)) _present.add(id);
    });
  }

  void _markAll() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _present.addAll(widget.roster.map((s) => s.id)));
  }

  Future<void> _record({String? reason, String? holder}) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(entryActionsProvider)
          .recordTripHeadcount(
            tripBlockId: widget.blockId,
            groupId: widget.groupId,
            leg: widget.leg,
            presentIds: _present.toList(),
            expected: _total,
            overrideReason: reason,
            overrideHolder: holder,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Object catch (_) {
      // Optimistic write failed (rare — Drift/RLS). Keep the sheet open so the
      // count isn't lost; let them retry. Reset the saving flag.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't save the headcount — try again."),
        ),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _confirmOverride() async {
    final result = await _showOverrideDialog(context, _missing);
    if (result == null || !mounted) return;
    await _record(reason: result.reason, holder: result.holder);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final countColor = _complete ? scheme.primary : scheme.error;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GlassDragHandle(),
              Text(
                '${TripLeg.label(widget.leg)} headcount',
                style: theme.textTheme.titleLarge,
              ),
              Text(
                TripLeg.sublabel(widget.leg, widget.destination),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${_present.length}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: countColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'of $_total on board',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (!_complete)
                    TextButton(
                      onPressed: _markAll,
                      child: const Text('Mark all aboard'),
                    ),
                ],
              ),
              if (!_complete && _total > 0) ...[
                const SizedBox(height: 4),
                _MissingBanner(missing: _missing),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in widget.roster)
                    _KidChip(
                      name: '${s.firstName} ${s.lastName}'.trim(),
                      present: _present.contains(s.id),
                      onTap: () => _toggle(s.id),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _total == 0
                    ? () => Navigator.of(context).pop()
                    : (_complete && !_saving)
                    ? _record
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  _total == 0
                      ? 'No children enrolled — close'
                      : _complete
                      ? 'All aboard · confirm $_total / $_total'
                      : 'Count everyone to confirm',
                ),
              ),
              if (!_complete && _total > 0) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _confirmOverride,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: Text(
                    _missing.length == 1
                        ? 'Leave without ${_missing.first.firstName} — needs a reason'
                        : 'Leave without ${_missing.length} kids — needs a reason',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingBanner extends StatelessWidget {
  const _MissingBanner({required this.missing});

  final List<Subject> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final names = missing.map((s) => s.firstName).take(3).join(', ');
    final extra = missing.length > 3 ? ' +${missing.length - 3} more' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              missing.length == 1
                  ? "$names isn't checked yet — find them before leaving."
                  : '$names$extra not checked yet — find them before leaving.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KidChip extends StatelessWidget {
  const _KidChip({
    required this.name,
    required this.present,
    required this.onTap,
  });

  final String name;
  final bool present;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bg = present ? scheme.primary : scheme.surfaceContainerHighest;
    final fg = present ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: present,
      label: '$name, ${present ? "on board" : "not checked"}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    present ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 17,
                    color: fg,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    name,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef _Override = ({String reason, String holder});

/// The reason-required override prompt — leaving without a kid demands who has
/// them + why, for the safety/licensing trail.
Future<_Override?> _showOverrideDialog(
  BuildContext context,
  List<Subject> missing,
) async {
  final reason = TextEditingController();
  final holder = TextEditingController();
  final names = missing
      .map((s) => '${s.firstName} ${s.lastName}'.trim())
      .join(', ');
  try {
    return await showDialog<_Override>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final ready =
                reason.text.trim().isNotEmpty && holder.text.trim().isNotEmpty;
            return AlertDialog(
              title: const Text('Leaving without a child'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Not accounted for: $names. This is logged with your name '
                    'and time. Say who has them and why.',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: holder,
                    onChanged: (_) => setLocal(() {}),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Who has them?',
                      hintText: 'Parent pickup · stayed with Ms. Lee',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reason,
                    onChanged: (_) => setLocal(() {}),
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: ready
                      ? () => Navigator.of(ctx).pop(
                          (
                            reason: reason.text.trim(),
                            holder: holder.text.trim(),
                          ),
                        )
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError,
                  ),
                  child: const Text('Log & leave'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    reason.dispose();
    holder.dispose();
  }
}
