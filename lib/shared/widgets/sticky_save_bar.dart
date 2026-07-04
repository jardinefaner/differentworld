import 'package:flutter/material.dart';

/// The bottom-sticky save bar on long edit forms (activity, vehicle):
/// pinned over the scrolling body inside the form's Stack, opaque on
/// `surface`, full-width button with an inline spinner while saving.
/// Composition-transparent, so it can sit directly in the Stack's
/// children list like the `Positioned` it wraps.
class StickySaveBar extends StatelessWidget {
  const StickySaveBar({
    required this.saving,
    required this.onSave,
    required this.label,
    super.key,
  });

  /// True while the save round-trip is in flight — disables the button
  /// and swaps the check for the spinner.
  final bool saving;

  final VoidCallback onSave;

  /// Button label — e.g. `isEdit ? 'Save changes' : 'Create activity'`.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(label),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
