import 'package:differentworld/features/games/game_settings.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';

/// The pre-game settings sheet (docs/FEATURE_CHECKLISTS.md — the Settings
/// contract). Renders [settings] seeded from [initial]; returns the chosen
/// values (keyed by `GameSetting.id`) on Apply, or null if dismissed.
Future<Map<String, Object?>?> showGameSettings(
  BuildContext context, {
  required List<GameSetting> settings,
  required Map<String, Object?> initial,
}) {
  return showGlassSheet<Map<String, Object?>>(
    context: context,
    builder: (_) => _GameSettingsSheet(settings: settings, initial: initial),
  );
}

class _GameSettingsSheet extends StatefulWidget {
  const _GameSettingsSheet({required this.settings, required this.initial});

  final List<GameSetting> settings;
  final Map<String, Object?> initial;

  @override
  State<_GameSettingsSheet> createState() => _GameSettingsSheetState();
}

class _GameSettingsSheetState extends State<_GameSettingsSheet> {
  late final Map<String, Object?> _values = Map<String, Object?>.of(
    widget.initial,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Game settings', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                for (final setting in widget.settings) ...[
                  _control(setting),
                  const SizedBox(height: 18),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_values),
                    child: const Text('Start a new round'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _control(GameSetting setting) => switch (setting) {
    final IntSetting s => _IntControl(
      setting: s,
      value: _values.intSetting(s.id, s.initial),
      onChanged: (v) => setState(() => _values[s.id] = v),
    ),
    final MultiSetting s => _MultiControl(
      setting: s,
      value: _values.multiSetting(s.id, s.initial),
      onChanged: (v) => setState(() => _values[s.id] = v),
    ),
  };
}

/// A labelled stepper for an [IntSetting], clamped to its range.
class _IntControl extends StatelessWidget {
  const _IntControl({
    required this.setting,
    required this.value,
    required this.onChanged,
  });

  final IntSetting setting;
  final int value;
  final ValueChanged<int> onChanged;

  void _bump(int delta) =>
      onChanged((value + delta).clamp(setting.min, setting.max));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                setting.label,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (setting.hint != null)
                Text(
                  setting.hint!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Less',
          onPressed: value > setting.min ? () => _bump(-setting.step) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'More',
          onPressed: value < setting.max ? () => _bump(setting.step) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// A row of toggle chips for a [MultiSetting] — at least one stays selected.
class _MultiControl extends StatelessWidget {
  const _MultiControl({
    required this.setting,
    required this.value,
    required this.onChanged,
  });

  final MultiSetting setting;
  final Set<String> value;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          setting.label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in setting.options)
              FilterChip(
                label: Text(option.label),
                selected: value.contains(option.value),
                onSelected: (on) {
                  final next = Set<String>.of(value);
                  if (on) {
                    next.add(option.value);
                  } else if (next.length > 1) {
                    // Keep at least one selected — a round needs something.
                    next.remove(option.value);
                  }
                  onChanged(next);
                },
              ),
          ],
        ),
      ],
    );
  }
}
