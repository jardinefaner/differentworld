import 'package:differentworld/features/settings/text_scale_setting.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Text-size override tile + picker — extracted from settings_screen.dart
/// so the Family lens (guardians never reach `/settings`) can offer the
/// same accessibility affordance through its own preferences entry.
///
/// Two public surfaces:
///   * [TextSizeTile] — the staff-side `ListTile`-with-chevron used in
///     Settings → Preferences. Tapping it opens [showTextSizePicker].
///   * [showTextSizePicker] — the bottom-sheet radio picker on its own,
///     callable directly from a guardian-facing action button (Family
///     Today header) so we don't need to host a full Settings screen
///     for guardians just to expose this one toggle.
///
/// Helen-persona note: the setting is layered on TOP of the OS dynamic-
/// type slider via `AppTextScaleApplier` (see `lib/app/app.dart`). The
/// shared sheet means staff + family see identical labels + subtitles,
/// no per-surface drift.
class TextSizeTile extends ConsumerWidget {
  const TextSizeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(textScaleSettingProvider);
    final mode = modeAsync.value ?? TextScaleMode.systemDefault;
    return ListTile(
      leading: const Icon(Icons.format_size_outlined),
      title: const Text('Text size'),
      subtitle: Text(mode.label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showTextSizePicker(context, ref),
    );
  }
}

/// Bottom-sheet picker for [TextScaleMode]. Renders the same RadioGroup
/// the staff Settings screen has shipped since the Helen-persona ship.
/// On selection: persists through [TextScaleSettingNotifier.set] and
/// pops the sheet. Safe to call from anywhere — guards `mounted` after
/// the awaited save and avoids re-entry by reading the current value
/// from the watching ref.
Future<void> showTextSizePicker(BuildContext context, WidgetRef ref) async {
  final currentAsync = ref.read(textScaleSettingProvider);
  final current = currentAsync.value ?? TextScaleMode.systemDefault;
  final picked = await showGlassSheet<TextScaleMode>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<TextScaleMode>(
                groupValue: current,
                onChanged: (m) {
                  if (m == null) return;
                  Navigator.of(sheetContext).pop(m);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final option in TextScaleMode.values)
                      RadioListTile<TextScaleMode>(
                        title: Text(option.label),
                        subtitle: Text(_subtitle(option)),
                        value: option,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (picked == null) return;
  // The sheet awaits the user — by the time it pops, the calling
  // surface may have been popped too (e.g. router went back behind
  // the sheet). Guard the `ref` use; `WidgetRef` from a stale
  // BuildContext asserts in debug and silently no-ops in release.
  if (!context.mounted) return;
  await ref.read(textScaleSettingProvider.notifier).set(picked);
}

String _subtitle(TextScaleMode option) => switch (option) {
  TextScaleMode.systemDefault =>
    'Use the size from your phone / tablet settings.',
  TextScaleMode.large => 'Boost everywhere — about 130% of the default.',
  TextScaleMode.extraLarge => 'Boost more — about 150%. Some labels may wrap.',
};
