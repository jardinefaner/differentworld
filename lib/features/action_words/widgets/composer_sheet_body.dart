import 'package:flutter/material.dart';

/// Shared scaffold for the small "write a thing" glass sheets (bury a time
/// capsule, add a wall note): safe-area scroll body, keyboard-aware padding,
/// a titleMedium heading, then the caller's fields stretched full-width.
class ComposerSheetBody extends StatelessWidget {
  const ComposerSheetBody({
    required this.title,
    required this.children,
    super.key,
  });
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
