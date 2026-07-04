import 'package:flutter/material.dart';

/// The submit button at the foot of a library edit form (locations, supplies,
/// pickup people, …) — a `FilledButton.icon` that stays DISABLED until the
/// form's required [requiredField] has text (no silent no-op tap), and swaps
/// its check icon for an inline spinner while [saving] (CLAUDE.md: disable
/// submit during submission, inline spinner in the button — never a
/// full-screen overlay).
class FormSaveButton extends StatelessWidget {
  const FormSaveButton({
    required this.requiredField,
    required this.onSave,
    required this.label,
    this.saving = false,
    super.key,
  });

  /// The controller of the form's one required field (usually the name).
  /// The button rebuilds as it changes and enables only when non-blank.
  final TextEditingController requiredField;

  /// True while the save round-trip is in flight — disables the button and
  /// shows the inline spinner.
  final bool saving;

  final VoidCallback onSave;

  /// Button label — e.g. `isEdit ? 'Save' : 'Add location'`.
  final String label;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: requiredField,
      builder: (context, value, _) {
        final canSave = !saving && value.text.trim().isNotEmpty;
        return FilledButton.icon(
          onPressed: canSave ? onSave : null,
          icon: saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(label),
        );
      },
    );
  }
}
