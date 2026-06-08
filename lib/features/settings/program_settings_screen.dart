import 'dart:async';

import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/house_timer.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/cap_switch.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Director-only screen: edit Space-level feature toggles & defaults.
///
/// Per `docs/UX_DECISIONS.md §1`, toggles **auto-save** — no Save
/// button, no draft state. Each `onChanged` fires
/// [SpaceCapActions.setCap] which reads the latest Space row, merges
/// the single change, and writes the blob back.
class ProgramSettingsScreen extends ConsumerStatefulWidget {
  const ProgramSettingsScreen({super.key});

  @override
  ConsumerState<ProgramSettingsScreen> createState() =>
      _ProgramSettingsScreenState();
}

class _ProgramSettingsScreenState extends ConsumerState<ProgramSettingsScreen> {
  Future<void> _setCap(String spaceId, String key, bool value) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final actions = ref.read(spaceCapActionsProvider);
    await runReported(
      library: 'settings',
      messenger: messenger,
      onError: "Couldn't save that change. Try again.",
      action: () => actions.setCap(spaceId, key, value),
    );
  }

  /// Vertical picker — flips the entire label system in one write.
  /// Childcare maps to `null` (the implicit default) so a fresh
  /// space without the cap stays on childcare.
  Future<void> _setVertical(String spaceId, String key) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final actions = ref.read(spaceCapActionsProvider);
    final value = key == 'childcare' ? null : key;
    await runReported(
      library: 'settings',
      messenger: messenger,
      onError: "Couldn't change the vertical. Try again.",
      action: () => actions.setStringCap(
        spaceId,
        SpaceCaps.vertical,
        value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    if (!viewer.canManageSpace) {
      return const EdgeScaffold(
        backFallbackRoute: '/settings',
        body: NoAccess(
          title: 'Only directors can edit program settings.',
          message: 'Ask the program director to make changes here.',
        ),
      );
    }
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      return const EdgeScaffold(
        backFallbackRoute: '/settings',
        body: EmptyState(
          icon: Icons.group_off_outlined,
          title: 'No space selected',
        ),
      );
    }
    final spaceAsync = ref.watch(_spaceProvider(spaceId));

    // No save action — toggles auto-save (UX_DECISIONS §1).
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      body: spaceAsync.when(
        loading: () => const LoadingSlot(),
        error: (e, _) =>
            const ErrorState(title: 'Could not load program settings'),
        data: (space) {
          if (space == null) {
            return const EmptyState(
              icon: Icons.group_off_outlined,
              title: 'No space',
            );
          }
          final caps = space.caps;
          return FormBody(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ContentHeader(
                  title: space.name,
                  subtitle: 'Program settings',
                  bottomGap: 8,
                ),
              ),
              const _SectionLabel(label: 'Vertical'),
              _VerticalPickerTile(
                currentKey:
                    caps.getString(SpaceCaps.vertical) ?? 'childcare',
                onChanged: (key) => _setVertical(spaceId, key),
              ),
              const _SectionLabel(label: "What's tracked"),
                CapSwitch(
                  label: 'Observations',
                  subtitle: 'Quick narrative + photo capture for kids',
                  value: caps.getBool(
                    SpaceCaps.featureObservations,
                    fallback: true,
                  ),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureObservations, v),
                ),
                CapSwitch(
                  label: 'Meal logging',
                  subtitle: 'Daily meals/snacks per child',
                  value: caps.getBool(
                    SpaceCaps.featureMealLogging,
                    fallback: true,
                  ),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureMealLogging, v),
                ),
                CapSwitch(
                  label: 'Nap logging',
                  subtitle: 'Start, end, and quality',
                  value: caps.getBool(
                    SpaceCaps.featureNapLogging,
                    fallback: true,
                  ),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureNapLogging, v),
                ),
                CapSwitch(
                  label: 'Diaper logging',
                  subtitle: 'Default off — enable for infant/toddler programs',
                  value: caps.getBool(SpaceCaps.featureDiaperLogging),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureDiaperLogging, v),
                ),
                CapSwitch(
                  label: 'Incident reports',
                  subtitle: 'Structured reports + parent notification',
                  value: caps.getBool(
                    SpaceCaps.featureIncidentReports,
                    fallback: true,
                  ),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureIncidentReports, v),
                ),
                CapSwitch(
                  label: 'Medication log',
                  subtitle:
                      'Track doses given (requires certified staff member)',
                  value: caps.getBool(SpaceCaps.featureMedicationLog),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureMedicationLog, v),
                ),
                CapSwitch(
                  label: 'Field trips',
                  subtitle: 'Trips + permission slips',
                  value: caps.getBool(SpaceCaps.featureFieldTrips),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureFieldTrips, v),
                ),
                CapSwitch(
                  label: 'Family login',
                  subtitle: 'Family-facing app access (coming soon)',
                  value: caps.getBool(SpaceCaps.featureFamilyLogin),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureFamilyLogin, v),
                ),
                CapSwitch(
                  label: 'Billing',
                  subtitle: 'Attendance-based invoicing (coming soon)',
                  value: caps.getBool(SpaceCaps.featureBilling),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.featureBilling, v),
                ),
                const _SectionLabel(label: 'Defaults'),
                CapSwitch(
                  label: 'Photo consent by default',
                  subtitle:
                      'New enrollments start with photo consent enabled. '
                      'Turn off if you require explicit per-family opt-in.',
                  value: caps.getBool(SpaceCaps.photoDefaultConsent),
                  onChanged: (v) => _setCap(spaceId,SpaceCaps.photoDefaultConsent, v),
                ),
                _TimerPresetsTile(spaceId: spaceId),
                _PlayLengthTile(spaceId: spaceId),
                const _SectionLabel(label: 'Day rhythm'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    'When the day shifts gears. The Today screen leads with '
                    'the right next move for each window — retime them for a '
                    'camp or full-day program.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _PhaseWindowsSection(spaceId: spaceId),
                const SizedBox(height: 32),
              ],
            );
        },
      ),
    );
  }

}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _spaceProvider = StreamProvider.autoDispose.family<Space?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.spacesDao.watchById(id);
  },
);

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Director editor for the program's **house timer presets** — the quick
/// durations on the present-surface timer (Play today / Present an activity).
/// Reads [houseTimerPresetsProvider] (program policy on the Space caps); the
/// row taps through to a glass sheet that adds/removes presets. Distinct from
/// each device's remembered customs and the per-beat suggestion.
class _TimerPresetsTile extends ConsumerWidget {
  const _TimerPresetsTile({required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presets = ref.watch(houseTimerPresetsProvider);
    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: const Text('Timer presets'),
      subtitle: Text(
        '${presets.join(', ')} min · the quick taps on the present timer',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showGlassSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _TimerPresetsSheet(spaceId: spaceId),
      ),
    );
  }
}

/// The program's default length for the Big Thinking play beat's suggested
/// timer — the *suggestion* layer of the timer (vs. the preset list above and
/// each device's remembered customs). A compact inline stepper, auto-saved.
/// Custom row (not ListTile) so the stepper never fights the trailing slot's
/// width on a narrow phone.
class _PlayLengthTile extends ConsumerWidget {
  const _PlayLengthTile({required this.spaceId});

  final String spaceId;

  Future<void> _set(BuildContext context, WidgetRef ref, int minutes) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    return runReported(
      library: 'settings',
      messenger: messenger,
      onError: "Couldn't save the play length. Try again.",
      action: () =>
          ref.read(houseTimerActionsProvider).setPlayMinutes(spaceId, minutes),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mins = ref.watch(houseSuggestPlayMinutesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Big Thinking play length',
                  style: theme.textTheme.bodyLarge,
                ),
                Text(
                  'Suggested timer on the play → name → bridge → question play.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Less',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: mins > kMinPresetMinutes
                ? () => unawaited(_set(context, ref, mins - 1))
                : null,
          ),
          SizedBox(
            width: 52,
            child: Text(
              '$mins min',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'More',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: mins < kMaxPresetMinutes
                ? () => unawaited(_set(context, ref, mins + 1))
                : null,
          ),
        ],
      ),
    );
  }
}

/// The four day-phase boundaries as time-picker rows. Editing one writes the
/// whole window set (the actions serialize). `DayPhaseWindows` decode forces
/// the boundaries strictly ascending, so an out-of-order pick self-corrects.
class _PhaseWindowsSection extends ConsumerWidget {
  const _PhaseWindowsSection({required this.spaceId});

  final String spaceId;

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    DayPhaseWindows windows,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    return runReported(
      library: 'settings',
      messenger: messenger,
      onError: "Couldn't save the day rhythm. Try again.",
      action: () =>
          ref.read(dayPhaseActionsProvider).setWindows(spaceId, windows),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final w = ref.watch(dayPhaseWindowsProvider);
    return Column(
      children: [
        _PhaseWindowRow(
          label: 'Arrival starts',
          minutes: w.arrivalStart,
          onPick: (m) =>
              unawaited(_save(context, ref, w.copyWith(arrivalStart: m))),
        ),
        _PhaseWindowRow(
          label: 'Activities start',
          minutes: w.programStart,
          onPick: (m) =>
              unawaited(_save(context, ref, w.copyWith(programStart: m))),
        ),
        _PhaseWindowRow(
          label: 'Pickup starts',
          minutes: w.pickupStart,
          onPick: (m) =>
              unawaited(_save(context, ref, w.copyWith(pickupStart: m))),
        ),
        _PhaseWindowRow(
          label: 'Day ends',
          minutes: w.closedStart,
          onPick: (m) =>
              unawaited(_save(context, ref, w.copyWith(closedStart: m))),
        ),
      ],
    );
  }
}

class _PhaseWindowRow extends StatelessWidget {
  const _PhaseWindowRow({
    required this.label,
    required this.minutes,
    required this.onPick,
  });

  final String label;
  final int minutes;
  final ValueChanged<int> onPick;

  Future<void> _pick(BuildContext context) async {
    final initial = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) onPick(picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return ListTile(
      leading: const Icon(Icons.schedule_outlined),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(t.format(context), style: theme.textTheme.titleSmall),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => unawaited(_pick(context)),
    );
  }
}

class _TimerPresetsSheet extends ConsumerStatefulWidget {
  const _TimerPresetsSheet({required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<_TimerPresetsSheet> createState() => _TimerPresetsSheetState();
}

class _TimerPresetsSheetState extends ConsumerState<_TimerPresetsSheet> {
  late List<int> _working;
  int _add = 5;

  static const _maxPresets = 6;

  @override
  void initState() {
    super.initState();
    _working = List<int>.of(ref.read(houseTimerPresetsProvider));
  }

  Future<void> _save(List<int> next) async {
    final clean = sanitizeTimerPresets(next);
    final effective = clean.isEmpty ? kDefaultTimerPresetMinutes : clean;
    setState(() => _working = effective);
    final messenger = ScaffoldMessenger.maybeOf(context);
    await runReported(
      library: 'settings',
      messenger: messenger,
      onError: "Couldn't save timer presets. Try again.",
      action: () => ref
          .read(houseTimerActionsProvider)
          .setPresetMinutes(widget.spaceId, effective),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canAdd = _working.length < _maxPresets && !_working.contains(_add);
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Timer presets', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'The quick durations a teacher taps on the present-surface '
              'timer. They can still dial any length — these are the shortcuts.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _working)
                  InputChip(
                    label: Text('$m min'),
                    onDeleted: _working.length > 1
                        ? () => unawaited(
                            _save([for (final x in _working) if (x != m) x]),
                          )
                        : null,
                  ),
              ],
            ),
            const Divider(height: 28),
            Text('Add a duration', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Less',
                  icon: const Icon(Icons.remove),
                  onPressed: _add > kMinPresetMinutes
                      ? () => setState(() => _add--)
                      : null,
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    '$_add min',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'More',
                  icon: const Icon(Icons.add),
                  onPressed: _add < kMaxPresetMinutes
                      ? () => setState(() => _add++)
                      : null,
                ),
                const Spacer(),
                FilledButton(
                  onPressed: canAdd
                      ? () => unawaited(_save([..._working, _add]))
                      : null,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => unawaited(_save(kDefaultTimerPresetMinutes)),
              child: const Text('Reset to default'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-tap vertical switcher. Flipping this re-labels Space / Member /
/// Group / Subject / Entry across the entire app on the next rebuild.
///
/// Renders a single tile so the picker is consistent with the other
/// settings rows (CapSwitch is the design language). Tapping the
/// trailing chevron opens a bottom sheet listing the five presets
/// with their full label preview — picking one auto-saves.
class _VerticalPickerTile extends StatelessWidget {
  const _VerticalPickerTile({
    required this.currentKey,
    required this.onChanged,
  });

  final String currentKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final current = labelsForVerticalKey(currentKey);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final picked = await showGlassSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (_) => _VerticalPickerSheet(currentKey: currentKey),
            );
            if (picked != null && picked != currentKey) {
              onChanged(picked);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _verticalLabel(currentKey),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        // Mini preview of the engine-noun mapping so
                        // the director sees what they'd be switching
                        // to (or already see today).
                        '${current.space} · ${current.group} · '
                        '${current.subjectPlural}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _verticalLabel(String key) {
    switch (key) {
      case 'construction':
        return 'Construction';
      case 'healthcare':
        return 'Healthcare';
      case 'hospitality':
        return 'Hospitality';
      case 'manufacturing':
        return 'Manufacturing';
      case 'childcare':
      default:
        return 'Childcare';
    }
  }
}

/// Bottom sheet body for the vertical picker — one row per preset
/// with its preview line. Tapping pops with the vertical key.
class _VerticalPickerSheet extends StatelessWidget {
  const _VerticalPickerSheet({required this.currentKey});

  final String currentKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick the vertical',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Re-labels Space, Member, Group, Subject, Entry across '
              'the app. Existing data stays in place; only labels '
              'change.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final preset in allVerticalPresets)
              _VerticalPickerRow(
                preset: preset,
                selected: preset.vertical == currentKey,
              ),
          ],
        ),
      ),
    );
  }
}

class _VerticalPickerRow extends StatelessWidget {
  const _VerticalPickerRow({
    required this.preset,
    required this.selected,
  });

  final VerticalLabels preset;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(preset.vertical),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _label(preset.vertical),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${preset.space} · ${preset.group} · '
                        '${preset.subjectPlural} · ${preset.entry}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer
                                  .withValues(alpha: 0.85)
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    color: scheme.onPrimaryContainer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _label(String key) {
    switch (key) {
      case 'construction':
        return 'Construction';
      case 'healthcare':
        return 'Healthcare';
      case 'hospitality':
        return 'Hospitality';
      case 'manufacturing':
        return 'Manufacturing';
      case 'childcare':
      default:
        return 'Childcare';
    }
  }
}
