import 'package:differentworld/core/capabilities/capabilities.dart';
import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Director-only screen: edit Space-level feature toggles & defaults.
class ProgramSettingsScreen extends ConsumerStatefulWidget {
  const ProgramSettingsScreen({super.key});

  @override
  ConsumerState<ProgramSettingsScreen> createState() =>
      _ProgramSettingsScreenState();
}

class _ProgramSettingsScreenState extends ConsumerState<ProgramSettingsScreen> {
  Capabilities? _draft;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final memberAsync = ref.watch(currentMemberProvider);
    final spaceId = memberAsync.value?.spaceId;
    if (spaceId == null) {
      return const EdgeScaffold(
        backFallbackRoute: '/settings',
        body: Center(child: Text('No space selected.')),
      );
    }
    final spaceAsync = ref.watch(_spaceProvider(spaceId));

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        if (_draft != null && spaceAsync.value != null)
          IconButton(
            tooltip: 'Save',
            onPressed: _saving ? null : () => _save(spaceAsync.value!),
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
      ],
      body: spaceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            const Center(child: Text('Could not load program settings.')),
        data: (space) {
          if (space == null) return const Center(child: Text('No space.'));
          final caps = _draft ?? space.caps;
          return ListView(
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
              const _SectionLabel(label: "What's tracked"),
                _CapSwitch(
                  label: 'Observations',
                  subtitle: 'Quick narrative + photo capture for kids',
                  value: caps.getBool(
                    SpaceCaps.featureObservations,
                    fallback: true,
                  ),
                  onChanged: (v) => _set(SpaceCaps.featureObservations, v),
                ),
                _CapSwitch(
                  label: 'Meal logging',
                  subtitle: 'Daily meals/snacks per child',
                  value: caps.getBool(
                    SpaceCaps.featureMealLogging,
                    fallback: true,
                  ),
                  onChanged: (v) => _set(SpaceCaps.featureMealLogging, v),
                ),
                _CapSwitch(
                  label: 'Nap logging',
                  subtitle: 'Start, end, and quality',
                  value: caps.getBool(
                    SpaceCaps.featureNapLogging,
                    fallback: true,
                  ),
                  onChanged: (v) => _set(SpaceCaps.featureNapLogging, v),
                ),
                _CapSwitch(
                  label: 'Diaper logging',
                  subtitle: 'Default off — enable for infant/toddler programs',
                  value: caps.getBool(SpaceCaps.featureDiaperLogging),
                  onChanged: (v) => _set(SpaceCaps.featureDiaperLogging, v),
                ),
                _CapSwitch(
                  label: 'Incident reports',
                  subtitle: 'Structured reports + parent notification',
                  value: caps.getBool(
                    SpaceCaps.featureIncidentReports,
                    fallback: true,
                  ),
                  onChanged: (v) => _set(SpaceCaps.featureIncidentReports, v),
                ),
                _CapSwitch(
                  label: 'Medication log',
                  subtitle:
                      'Track doses given (requires certified staff member)',
                  value: caps.getBool(SpaceCaps.featureMedicationLog),
                  onChanged: (v) => _set(SpaceCaps.featureMedicationLog, v),
                ),
                _CapSwitch(
                  label: 'Field trips',
                  subtitle: 'Trips + permission slips',
                  value: caps.getBool(SpaceCaps.featureFieldTrips),
                  onChanged: (v) => _set(SpaceCaps.featureFieldTrips, v),
                ),
                _CapSwitch(
                  label: 'Family login',
                  subtitle: 'Family-facing app access (coming soon)',
                  value: caps.getBool(SpaceCaps.featureFamilyLogin),
                  onChanged: (v) => _set(SpaceCaps.featureFamilyLogin, v),
                ),
                _CapSwitch(
                  label: 'Billing',
                  subtitle: 'Attendance-based invoicing (coming soon)',
                  value: caps.getBool(SpaceCaps.featureBilling),
                  onChanged: (v) => _set(SpaceCaps.featureBilling, v),
                ),
                const _SectionLabel(label: 'Defaults'),
                _CapSwitch(
                  label: 'Photo consent by default',
                  subtitle:
                      'New enrollments start with photo consent enabled. '
                      'Turn off if you require explicit per-family opt-in.',
                  value: caps.getBool(SpaceCaps.photoDefaultConsent),
                  onChanged: (v) => _set(SpaceCaps.photoDefaultConsent, v),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      _error!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            );
        },
      ),
    );
  }

  void _set(String key, bool value) {
    // Null-safe baseline: don't risk a bang-crash if the current
    // member or space stream hasn't resolved yet.
    Capabilities baseline() {
      if (_draft != null) return _draft!;
      final spaceId = ref.read(currentMemberProvider).value?.spaceId;
      if (spaceId == null) return const Capabilities.empty();
      return ref.read(_spaceProvider(spaceId)).value?.caps ??
          const Capabilities.empty();
    }

    setState(() {
      _draft = baseline().setting(key, value);
    });
  }

  Future<void> _save(Space space) async {
    final draft = _draft;
    if (draft == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final db = await ref.read(appDatabaseProvider.future);
      await db.updateSpaceCapabilities(space.id, draft.toJson());
      if (!mounted) return;
      setState(() => _draft = null);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'settings'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// Riverpod 3 family providers don't have a stable public-typed name.
// ignore: specify_nonobvious_property_types
final _spaceProvider = StreamProvider.autoDispose.family<Space?, String>(
  (ref, id) async* {
    final db = await ref.watch(appDatabaseProvider.future);
    yield* db.watchSpace(id);
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
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: onChanged,
    );
  }
}
