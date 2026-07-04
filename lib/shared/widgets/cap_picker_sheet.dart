import 'package:flutter/material.dart';

/// Glass-sheet body for a "pick one; empty string clears" capability
/// picker (room theme, crew): a title + one-line subtitle above the
/// option rows, plus an optional destructive clear row that pops `''`
/// (the caller's convention for "clear the cap"). Rows are supplied by
/// the caller so each picker keeps its own preview shape.
class CapPickerSheetBody extends StatelessWidget {
  const CapPickerSheetBody({
    required this.title,
    required this.subtitle,
    required this.children,
    this.clearLabel,
    this.titleBottomPad = 4,
    super.key,
  });

  final String title;
  final String subtitle;

  /// The option rows, spliced between the subtitle and the clear row.
  final List<Widget> children;

  /// When non-null, renders the destructive "clear" row (pops `''`).
  final String? clearLabel;

  /// Bottom padding under the title (the pickers differ by a hair).
  final double titleBottomPad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, titleBottomPad),
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ...children,
              if (clearLabel case final label?)
                ListTile(
                  leading: Icon(Icons.clear, color: theme.colorScheme.error),
                  title: Text(
                    label,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  // Empty string = the caller clears the cap.
                  onTap: () => Navigator.of(context).pop(''),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
