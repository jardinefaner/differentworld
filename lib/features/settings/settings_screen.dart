import 'dart:async';

import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/core/capabilities/role_labels.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/live_session/room_screen_setting.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_source_sheet.dart';
import 'package:differentworld/features/settings/cockpit_home_setting.dart';
import 'package:differentworld/features/settings/display_style_setting.dart';
import 'package:differentworld/features/settings/font_choice.dart';
import 'package:differentworld/features/settings/outdoor_mode_setting.dart';
import 'package:differentworld/features/settings/widgets/text_size_tile.dart';
import 'package:differentworld/shared/widgets/capability_locked_tile.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
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
      body: FormBody(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ContentHeader(title: 'Settings', bottomGap: 8),
          ),

          // Account — uses viewer.displayName so the right identity
          // renders for staff (member.displayName) AND guardians
          // (guardian.name). Avatar tap → open the photo-change sheet
          // when the viewer has a member row (staff path); guardians
          // tap their identity row to land on their own family
          // profile in a future revision.
          _SettingsGroup(
            label: 'Signed in as',
            children: [
              ListTile(
                leading: PersonAvatar(
                  name: viewer.displayName.isEmpty
                      ? '?'
                      : viewer.displayName,
                  photoUrl: member?.avatarUrl,
                  onTap: member == null
                      ? null
                      : () => PhotoSourceSheet.show(
                            context,
                            entity: PhotoEntity.member,
                            entityId: member.id,
                            hasExisting: member.avatarUrl != null,
                            displayName: viewer.displayName,
                          ),
                ),
                title: Text(
                  viewer.displayName.isEmpty
                      ? '—'
                      : viewer.displayName,
                ),
                subtitle: Text(
                  viewer is GuardianViewer
                      ? 'Family'
                      : RoleLabels.of(
                          member?.role,
                          vertical: labels.vertical,
                        ),
                  style: theme.textTheme.bodySmall,
                ),
                // Tap the row → open the member detail (own profile)
                // for staff; guardians have no member detail screen,
                // so the row stays informational for them.
                onTap: member == null
                    ? null
                    : () => context.push('/settings/team/${member.id}'),
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
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Roles & permissions'),
                subtitle: const Text(
                  'What each role can do by default',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/roles'),
              ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.directions_bus_outlined),
                title: const Text('Vehicles'),
                subtitle: const Text(
                  'Fleet vehicles, pre-trip checks, check-in/out',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/vehicles'),
              ),
            ],
          ),

          // Library management (Activities / Locations) intentionally
          // lives in the omnibox now, not in Settings. The bottom
          // composer is the spine for "find / open / manage" — typing
          // "activities" or "locations" surfaces the screens. Keeping
          // them in Settings too made the menu busier without adding
          // a new path. Settings is now preferences-only.

          // Resources — editorial reference content that ships with
          // the binary. The Teacher Toolkit is the first one;
          // anything else that's "read-only library of curated
          // moves / phrases / scripts" lives here too.
          _SettingsGroup(
            label: 'Resources',
            children: [
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text('Teacher Toolkit'),
                subtitle: const Text(
                  'Sentences you can say, moves you can make, in the '
                  'moment',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/toolkit'),
              ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Through My Eyes'),
                subtitle: const Text(
                  'A 3-week / 6-session photography curriculum for ages 5–7',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/curricula/photo'),
              ),
              const _SettingsDivider(),
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text('Poster'),
                subtitle: const Text(
                  'Blow up an image across printed pages to tape together',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/poster'),
              ),
            ],
          ),

          // Preferences — appearance / text size / language. Appearance
          // and language are still placeholders (their detail screens
          // aren't built); the text-size override is live so Helen-
          // type users can boost the UI above their OS dynamic-type
          // slider without leaving Different World.
          _SettingsGroup(
            label: 'Preferences',
            children: [
              const TextSizeTile(),
              const _SettingsDivider(),
              const _OutdoorModeTile(),
              const _SettingsDivider(),
              const _DisplayStyleTile(),
              const _SettingsDivider(),
              const _FontChoiceTile(),
              const _SettingsDivider(),
              const _RoomScreenTile(),
              const _SettingsDivider(),
              // The clock-driven cockpit (docs/COCKPIT.md) — opt-in while it
              // proves itself; the plan is for it to become the home surface.
              ListTile(
                leading: const Icon(Icons.center_focus_strong_outlined),
                title: const Text('Now — the cockpit'),
                subtitle: const Text(
                  'One screen at a time, led by the clock (beta)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/now'),
              ),
              const _SettingsDivider(),
              const _CockpitHomeTile(),
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

/// The Calm-layout toggle (docs/VISION.md, 2026-06-14). On (the default) →
/// neutral cards become flush rows on one left edge (chrome hangs in the
/// gutter), so a list reads as one continuous surface instead of a stack of
/// boxes; signal cards keep their tint. Toggle off to revert to boxed cards.
/// Toggles whether the clock-driven cockpit takes the home slot
/// (docs/COCKPIT.md slice 4). Off by default; Today is never lost — it stays
/// reachable at /today (the cockpit's "More places").
class _CockpitHomeTile extends ConsumerWidget {
  const _CockpitHomeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(cockpitAsHomeProvider).value ?? false;
    return SwitchListTile(
      secondary: const Icon(Icons.home_outlined),
      title: const Text('Cockpit as home'),
      subtitle: const Text(
        'Open into the clock-driven screen; Today moves to More places',
      ),
      value: on,
      onChanged: (v) =>
          unawaited(ref.read(cockpitAsHomeProvider.notifier).set(value: v)),
    );
  }
}

class _DisplayStyleTile extends ConsumerWidget {
  const _DisplayStyleTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(displayStyleProvider).value ?? DisplayStyle.calm;
    return ListTile(
      leading: const Icon(Icons.view_agenda_outlined),
      title: const Text('Display style'),
      subtitle: Text(style.description),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final picked = await showGlassSheet<DisplayStyle>(
          context: context,
          showDragHandle: true,
          builder: (sheetContext) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                child: RadioGroup<DisplayStyle>(
                  groupValue: style,
                  onChanged: (s) {
                    if (s == null) return;
                    Navigator.of(sheetContext).pop(s);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final option in DisplayStyle.values)
                        RadioListTile<DisplayStyle>(
                          title: Text(option.label),
                          subtitle: Text(option.description),
                          value: option,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
        if (picked != null) {
          await ref.read(displayStyleProvider.notifier).set(picked);
        }
      },
    );
  }
}

/// Font picker — choose the display (headline) + body face from 10 each. The
/// bundled Fraunces + Space Grotesk default is offline-safe; other picks fetch
/// + cache via google_fonts on first use. Applies live (the theme re-skins on
/// select), so it doubles as the experimentation surface for settling fonts.
class _FontChoiceTile extends ConsumerWidget {
  const _FontChoiceTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(fontChoiceProvider).value ?? FontChoice.fallback;
    return ListTile(
      leading: const Icon(Icons.text_fields_outlined),
      title: const Text('Fonts'),
      subtitle: Text('${choice.display} · ${choice.body}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showGlassSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => const _FontPickerSheet(),
      ),
    );
  }
}

class _FontPickerSheet extends ConsumerWidget {
  const _FontPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(fontChoiceProvider).value ?? FontChoice.fallback;
    final theme = Theme.of(context);
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
          child: Text(
            text.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        children: [
          header('Display · headlines'),
          for (final o in kDisplayFonts)
            _FontRow(
              option: o,
              big: true,
              selected: o.family == choice.display,
              onTap: () =>
                  ref.read(fontChoiceProvider.notifier).setDisplay(o.family),
            ),
          header('Body · everything else'),
          for (final o in kBodyFonts)
            _FontRow(
              option: o,
              big: false,
              selected: o.family == choice.body,
              onTap: () =>
                  ref.read(fontChoiceProvider.notifier).setBody(o.family),
            ),
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.option,
    required this.big,
    required this.selected,
    required this.onTap,
  });

  final FontOption option;
  final bool big;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Preview each option IN its own face, so the picker reads like a type
    // specimen rather than a list of names.
    final preview = TextStyle(
      fontSize: big ? 22 : 16,
      fontWeight: FontWeight.w400,
      color: theme.colorScheme.onSurface,
    );
    return ListTile(
      dense: true,
      onTap: onTap,
      title: Text(option.family, style: styleIn(option, preview)),
      subtitle: option.bundled
          ? Text(
              'Bundled · always offline',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: selected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
    );
  }
}

/// Make THIS device the program's persistent room screen — the cast receiver
/// the room shows it big on. Set once; opening Cast then lands straight in
/// receiver mode on the program channel (no code), and it persists across
/// launches. Turning it off stops this device being the screen.
class _RoomScreenTile extends ConsumerWidget {
  const _RoomScreenTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isScreen = ref.watch(roomScreenFollowsProvider).value != null;
    return SwitchListTile(
      secondary: const Icon(Icons.tv_outlined),
      title: const Text('Room screen'),
      subtitle: Text(
        isScreen
            ? 'This device follows your cast as a room screen.'
            : 'Make this TV or tablet a screen that follows your cast.',
      ),
      value: isScreen,
      onChanged: (v) async {
        if (v) {
          // Setup follows MY controller code (CastScreen ?role=screen derives
          // it + persists the follow).
          if (context.mounted) unawaited(context.push('/cast?role=screen'));
        } else {
          await ref.read(roomScreenFollowsProvider.notifier).stop();
        }
      },
    );
  }
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
        final picked = await showGlassSheet<OutdoorMode>(
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
