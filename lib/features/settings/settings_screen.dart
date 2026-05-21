import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_source_sheet.dart';
import 'package:differentworld/features/settings/outdoor_mode_setting.dart';
import 'package:differentworld/features/settings/text_scale_setting.dart';
import 'package:differentworld/shared/widgets/capability_locked_tile.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Settings index — list of sections (Account / Program / About).
/// Each row navigates to a focused detail screen.
///
/// Sections are rendered inside grouped containers so they read as
/// iOS-style grouped lists — clearer hierarchy than a flat stack of
/// `ListTile`s with dividers.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final viewer = ref.watch(viewerProvider);
    final labels = ref.watch(verticalLabelsProvider);
    final member = viewer.member;

    return EdgeScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(title: 'Settings', bottomGap: 8),
          ),

          // Account
          _SettingsGroup(
            label: 'Signed in as',
            children: [
              ListTile(
                leading: PersonAvatar(
                  name: member?.displayName ?? '?',
                  photoUrl: member?.avatarUrl,
                  onTap: member == null
                      ? null
                      : () => PhotoSourceSheet.show(
                            context,
                            entity: PhotoEntity.member,
                            entityId: member.id,
                            hasExisting: member.avatarUrl != null,
                            displayName: member.displayName,
                          ),
                ),
                title: Text(member?.displayName ?? '—'),
                subtitle: Text(
                  _roleLabel(member?.role),
                  style: theme.textTheme.bodySmall,
                ),
                trailing: TextButton.icon(
                  onPressed: () async {
                    final ok = await _confirmSignOut(context);
                    if (!ok) return;
                    await ref.read(authActionsProvider).signOut();
                  },
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),

          // Space-level settings (label is vertical-aware — "Program"
          // for childcare, "Company" for construction, etc.)
          _SettingsGroup(
            label: labels.space,
            children: [
              // Brianna-persona: rather than greying out silently
              // when a teacher taps "Program settings", we explain
              // why with the lock chip + tooltip-snackbar. The
              // affordance stays visible so the new hire learns the
              // permission model.
              if (viewer.canManageSpace)
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Program settings'),
                  subtitle: const Text(
                    "What's tracked program-wide, pickup window, "
                    'defaults',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/program'),
                )
              else
                const CapabilityLockedTile(
                  tooltip:
                      'Only directors can change program settings. '
                      'Ask yours if something needs to update.',
                  child: ListTile(
                    leading: Icon(Icons.school_outlined),
                    title: Text('Program settings'),
                    subtitle: Text(
                      "What's tracked program-wide, pickup window, "
                      'defaults',
                    ),
                    trailing: Icon(Icons.chevron_right),
                  ),
                ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: const Text('Team'),
                subtitle: const Text('Members and their abilities'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/team'),
              ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.directions_bus_outlined),
                title: const Text('Vehicles'),
                subtitle: const Text(
                  'Fleet vehicles, pre-trip checks, check-in/out',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/vehicles'),
              ),
            ],
          ),

          // Library management (Activities / Locations) intentionally
          // lives in the omnibox now, not in Settings. The bottom
          // composer is the spine for "find / open / manage" — typing
          // "activities" or "locations" surfaces the screens. Keeping
          // them in Settings too made the menu busier without adding
          // a new path. Settings is now preferences-only.

          // Preferences — appearance / text size / language. Appearance
          // and language are still placeholders (their detail screens
          // aren't built); the text-size override is live so Helen-
          // type users can boost the UI above their OS dynamic-type
          // slider without leaving Different World.
          const _SettingsGroup(
            label: 'Preferences',
            children: [
              _TextSizeTile(),
              _SettingsDivider(),
              _OutdoorModeTile(),
            ],
          ),

          // About — version + privacy commitment. The privacy row is
          // non-negotiable for v1; childcare regulators read this.
          _SettingsGroup(
            label: 'About',
            children: [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Different World'),
                subtitle: Text('v0.1 · offline-first classroom logging'),
              ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy & data'),
                subtitle: const Text(
                  "How we handle children's information",
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Different World',
                    applicationVersion: 'v0.1',
                    children: const [
                      SizedBox(height: 8),
                      Text(
                        "Children's data lives on this device first. "
                        'It syncs to a private Supabase project under '
                        'your program. We never sell or share it.',
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Parents or directors can request a full data '
                        'export or deletion at any time — email your '
                        'program director.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Use the single RoleLabels source. The "—" empty fallback that
  // this previously used differs from RoleLabels.of's default
  // ("Signed in") — but the only call site uses this to subtitle a
  // member tile, where "Signed in" is the saner default for null.
  String _roleLabel(String? role) => RoleLabels.of(role);

  /// Sign-out is a one-way action that wipes the user's view; a small
  /// confirm step prevents fat-finger accidents on the avatar row.
  Future<bool> _confirmSignOut(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'Your local data stays on this device. You can sign in '
              'again anytime.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

/// Grouped settings container — iOS-style label above, soft-tinted
/// rounded box around the children. Replaces the flat stream of
/// `ListTile`s + dividers that read as a checkbox list.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Material(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(
            alpha: 0.4,
          ),
    );
  }
}

/// Text-size override picker. Default leaves the OS dynamic-type
/// slider in charge; "Large" or "Extra large" clamps to a higher
/// floor (1.3x / 1.5x) so users like the Helen persona can boost the
/// Different World UI without changing their device-wide font size.
///
/// The shim that actually applies the override lives in
/// `lib/app/app.dart` (AppTextScaleApplier wrapper around
/// MaterialApp's builder). This tile just persists the user's pick.
class _TextSizeTile extends ConsumerWidget {
  const _TextSizeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(textScaleSettingProvider);
    final mode = modeAsync.value ?? TextScaleMode.systemDefault;
    return ListTile(
      leading: const Icon(Icons.format_size_outlined),
      title: const Text('Text size'),
      subtitle: Text(mode.label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<TextScaleMode>(
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
                    // RadioGroup is the supported wrapper post-3.32.0;
                    // each RadioListTile inside it reads the group
                    // value and reports changes up through this single
                    // onChanged. Popping the sheet with the picked
                    // mode lets the caller persist it.
                    RadioGroup<TextScaleMode>(
                      groupValue: mode,
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
        if (picked != null) {
          await ref.read(textScaleSettingProvider.notifier).set(picked);
        }
      },
    );
  }

  static String _subtitle(TextScaleMode option) => switch (option) {
        TextScaleMode.systemDefault =>
          'Use the size from your phone / tablet settings.',
        TextScaleMode.large => 'Boost everywhere — about 130% of the default.',
        TextScaleMode.extraLarge =>
          'Boost more — about 150%. Some labels may wrap.',
      };
}

/// Outdoor (high-contrast) mode picker. Jordan persona's daily
/// reality is glare + clipboard + a phone-in-one-hand; the
/// pastel Material 3 surface tones get washed out. ON forces a
/// black-background safety-yellow theme regardless of OS
/// brightness.
class _OutdoorModeTile extends ConsumerWidget {
  const _OutdoorModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modeAsync = ref.watch(outdoorModeProvider);
    final mode = modeAsync.value ?? OutdoorMode.systemDefault;
    return ListTile(
      leading: const Icon(Icons.wb_sunny_outlined),
      title: const Text('Outdoor mode'),
      subtitle: Text(mode.label),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showModalBottomSheet<OutdoorMode>(
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
                    // Same RadioGroup pattern as _TextSizeTile —
                    // post-3.32 supported wrapper, single
                    // onChanged.
                    RadioGroup<OutdoorMode>(
                      groupValue: mode,
                      onChanged: (m) {
                        if (m == null) return;
                        Navigator.of(sheetContext).pop(m);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final option in OutdoorMode.values)
                            RadioListTile<OutdoorMode>(
                              title: Text(option.label),
                              subtitle: Text(option.description),
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
        if (picked != null) {
          await ref.read(outdoorModeProvider.notifier).set(picked);
        }
      },
    );
  }
}
