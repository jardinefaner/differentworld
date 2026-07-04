import 'dart:async';

import 'package:differentworld/features/identity/archetypes.dart';
import 'package:differentworld/features/settings/settings_actions.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The identity card's archetype line (docs/IDENTITY_SYSTEM.md §2 — "how you
/// show up"). Shows the member's chosen archetype; on the viewer's OWN profile
/// it's tappable to pick (self-authored — never editable on someone else's).
/// Renders nothing when unset on another person's profile.
class ArchetypeCard extends ConsumerWidget {
  const ArchetypeCard({
    required this.memberId,
    required this.archetypeId,
    required this.editable,
    super.key,
  });

  final String memberId;
  final String? archetypeId;
  final bool editable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final a = archetypeById(archetypeId);

    if (a == null) {
      if (!editable) return const SizedBox.shrink();
      return Center(
        child: OutlinedButton.icon(
          icon: const Icon(Icons.face_retouching_natural_outlined),
          label: const Text('Choose how you show up'),
          onPressed: () => unawaited(
            showArchetypePicker(context, ref, memberId, archetypeId),
          ),
        ),
      );
    }

    final chip = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          Text('${a.glyph}  ${a.name}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            a.essence,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );

    if (!editable) return Center(child: chip);
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            unawaited(showArchetypePicker(context, ref, memberId, archetypeId)),
        child: chip,
      ),
    );
  }
}

/// Self-authored picker — the 8 archetypes + a clear option. Writes through
/// [MemberCapActions.setArchetype] (a string cap; decorates, never gates).
Future<void> showArchetypePicker(
  BuildContext context,
  WidgetRef ref,
  String memberId,
  String? currentId,
) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final theme = Theme.of(sheetCtx);
      void choose(String? id) {
        unawaited(
          ref.read(memberCapActionsProvider).setArchetype(memberId, id),
        );
        Navigator.of(sheetCtx).pop();
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GlassDragHandle(),
              Text(
                'How do you show up?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your archetype is yours — it warms your screen, never limits '
                'it. No archetype is lesser.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final a in kArchetypes)
                _ArchetypeRow(
                  archetype: a,
                  selected: a.id == currentId,
                  onTap: () => choose(a.id),
                ),
              if (currentId != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => choose(null),
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _ArchetypeRow extends StatelessWidget {
  const _ArchetypeRow({
    required this.archetype,
    required this.selected,
    required this.onTap,
  });

  final Archetype archetype;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(archetype.glyph, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            archetype.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? scheme.onPrimaryContainer
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              archetype.gift,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: selected
                                    ? scheme.onPrimaryContainer.withValues(
                                        alpha: 0.8,
                                      )
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        archetype.essence,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: scheme.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
