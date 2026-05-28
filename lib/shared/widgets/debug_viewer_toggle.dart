import 'dart:async';

import 'package:differentworld/core/capabilities/role_keys.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/core/viewer/viewer_override.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wave 168 — dev-mode lens swap.
///
/// A small pill that lives in the AppShell's chrome action slot
/// alongside any route-specific actions. Tapping it opens a popup
/// listing the staff roles (Director / Lead Teacher / Teacher /
/// Substitute / Specialist / Kitchen) plus "Live" to clear. The
/// `viewerKindOverrideProvider` write swaps the viewer the rest of
/// the app sees; every capability-gated surface (omnibox, drawer,
/// settings tiles, Today cards, Schedule "+" button, etc.) rerenders
/// with that role's default cap bundle.
///
/// The badge shows the active override role label ("Teacher") or "Live"
/// when there's no override. Compiled out of release builds via
/// `kDebugMode` — the build method returns SizedBox.shrink so the
/// widget is free to leave in the AppShell layout unconditionally.
///
/// Not intended for guardian impersonation today — the family lens
/// depends on real guardian + subject_guardians rows. Future work
/// could add a "Guardian (synthetic)" entry that wires fake child IDs
/// for offline UI testing.
class DebugViewerToggle extends ConsumerWidget {
  const DebugViewerToggle({super.key});

  /// Roles the toggle offers. Order matches the role hierarchy so the
  /// menu reads top-down by authority.
  static const _roles = <String>[
    RoleKey.director,
    RoleKey.leadTeacher,
    RoleKey.teacher,
    RoleKey.substitute,
    RoleKey.specialist,
    RoleKey.kitchen,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!kDebugMode) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final override = ref.watch(viewerKindOverrideProvider);
    final realViewer = ref.watch(viewerProvider);
    final label = override == null ? 'Live' : RoleLabels.of(override);
    final isOverridden = override != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message:
            'Debug · view as a different role. Currently: $label.',
        child: Material(
          color: isOverridden
              ? theme.colorScheme.tertiaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: PopupMenuButton<String?>(
            tooltip: 'View as…',
            onOpened: () {
              unawaited(HapticFeedback.selectionClick());
            },
            onSelected: (value) {
              if (value == null || value.isEmpty) {
                ref.read(viewerKindOverrideProvider.notifier).clear();
              } else {
                ref.read(viewerKindOverrideProvider.notifier).set(value);
              }
            },
            itemBuilder: (ctx) {
              return [
                PopupMenuItem<String?>(
                  child: Row(
                    children: [
                      Icon(
                        override == null
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      const Text('Live (real account)'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                for (final r in _roles)
                  PopupMenuItem<String?>(
                    value: r,
                    child: Row(
                      children: [
                        Icon(
                          override == r
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(RoleLabels.of(r)),
                      ],
                    ),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem<String?>(
                  enabled: false,
                  child: Text(
                    'Real: ${realViewer.member?.displayName ?? "—"} · '
                    '${realViewer.member?.role ?? "—"}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ];
            },
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.face_retouching_natural_outlined,
                    size: 16,
                    color: isOverridden
                        ? theme.colorScheme.onTertiaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isOverridden
                          ? theme.colorScheme.onTertiaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
