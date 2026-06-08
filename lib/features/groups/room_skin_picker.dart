import 'dart:async';

import 'package:differentworld/core/capabilities/capability_keys.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/groups/room_skin_background.dart';
import 'package:differentworld/features/groups/room_skins.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tappable chip showing a room's theme skin (or a prompt to set one),
/// for the group detail screen. Tap → a skin picker. The room's PERMANENT
/// theme (docs/VISION.md "two layers of skin"); the weekly curriculum world
/// sits on top.
class RoomSkinChip extends ConsumerWidget {
  const RoomSkinChip({required this.group, super.key});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final skin = roomSkinForGroup(group);
    final accent = skin?.color ?? theme.colorScheme.outline;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _pick(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(skin?.emoji ?? '🎨', style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  skin == null ? 'Set room theme' : skin.name,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: skin == null
                        ? theme.colorScheme.onSurfaceVariant
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 14, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final current = roomSkinForGroup(group)?.id;
    final picked = await showGlassSheet<String>(
      context: context,
      builder: (_) => _SkinSheet(currentId: current),
    );
    if (picked == null) return; // cancelled
    await ref.read(groupCapActionsProvider).setStringCap(
          group.id,
          GroupCaps.roomSkin,
          picked.isEmpty ? null : picked, // '' = clear
        );
  }
}

class _SkinSheet extends StatelessWidget {
  const _SkinSheet({this.currentId});
  final String? currentId;

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
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text('Room theme', style: theme.textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'The room’s standing vibe. The weekly world sits on top.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final s in kRoomSkins)
                _SkinPreviewTile(
                  skin: s,
                  selected: s.id == currentId,
                  onTap: () => Navigator.of(context).pop(s.id),
                ),
              if (currentId != null)
                ListTile(
                  leading: Icon(Icons.clear, color: theme.colorScheme.error),
                  title: Text('Clear theme',
                      style: TextStyle(color: theme.colorScheme.error)),
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

/// One skin option, previewed as its actual ambient background with the name
/// in white over it — so the picker IS the gallery.
class _SkinPreviewTile extends StatelessWidget {
  const _SkinPreviewTile({
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final RoomSkin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 66,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RoomSkinBackground(skin: skin),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(skin.emoji, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            skin.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
