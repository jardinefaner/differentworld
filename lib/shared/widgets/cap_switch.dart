import 'package:flutter/material.dart';

/// `SwitchListTile` styled for capability/setting toggles across the
/// app — used on Member Detail, Program Settings, Group Edit, and
/// anywhere else a single boolean capability is flipped.
///
/// Per `docs/UX_DECISIONS.md §1`, the underlying mutator should
/// auto-save in `onChanged`; this widget just renders the control.
///
/// Why one shared widget instead of three private ones: see §9
/// (one canonical destination per action). Three private copies
/// quietly diverged on `dense:`, contentPadding, and subtitle
/// rendering. Now they share.
class CapSwitch extends StatelessWidget {
  const CapSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    this.dense = false,
    this.contentPadding,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  /// Match Material's `dense` flag. Default false to keep tap targets
  /// at the comfortable 56dp height; pass `dense: true` for grouped
  /// short-label settings (e.g. the per-classroom tracking list).
  final bool dense;

  /// Override the default `SwitchListTile` content padding. Use
  /// `EdgeInsets.zero` on screens that already pad their list views
  /// horizontally so the row aligns flush with sibling content.
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: enabled ? onChanged : null,
      dense: dense,
      contentPadding: contentPadding,
    );
  }
}
