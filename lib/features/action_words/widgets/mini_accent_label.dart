import 'package:flutter/material.dart';

/// Tiny uppercase accent eyebrow used above a focus block (journey day
/// sheet, the program hub tiles).
class MiniAccentLabel extends StatelessWidget {
  const MiniAccentLabel({required this.text, required this.accent, super.key});
  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: accent,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
      ),
    );
  }
}
