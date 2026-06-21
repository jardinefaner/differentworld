import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/activity_runtime/roles.dart';
import 'package:differentworld/features/entities/entity_ref.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/schedule/activities_providers.dart';
import 'package:differentworld/features/schedule/locations_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/vehicles/vehicles_providers.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

T? _byId<T>(List<T> xs, String id, String Function(T) idOf) {
  for (final x in xs) {
    if (idOf(x) == id) return x;
  }
  return null;
}

/// The ONE detail peek for every kind of named thing — a glass sheet showing
/// who/what it is, a few facts, and an "open full →" into its real screen.
/// Tap any [EntityRef] anywhere (a structured chip, an autotagged name) and
/// this opens. Resolves live from the same local list providers the index is
/// built from, so it's always current and never hits the network.
Future<void> showEntityPeek(BuildContext context, EntityRef entity) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetCtx) => _EntityPeekBody(
      entity: entity,
      onOpen: (route) {
        Navigator.of(sheetCtx).pop();
        // The outer context is the screen that opened the peek — stable across
        // the sheet pop (the post-pop-dispatch rule). Guard on mounted in case
        // the screen itself popped while the peek was open.
        if (context.mounted) unawaited(context.push(route));
      },
    ),
  );
}

class _EntityPeekBody extends ConsumerWidget {
  const _EntityPeekBody({required this.entity, required this.onOpen});

  final EntityRef entity;
  final void Function(String route) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (entity.kind) {
      case EntityKind.subject:
        final s = _byId(
          ref.watch(subjectsInSpaceProvider).value ?? const <Subject>[],
          entity.id,
          (x) => x.id,
        );
        final name = s == null
            ? entity.label
            : [s.firstName, s.lastName]
                .where((p) => p.trim().isNotEmpty)
                .join(' ');
        final group = s?.groupId == null
            ? null
            : _byId(ref.watch(groupsProvider).value ?? const <Group>[],
                s!.groupId!, (g) => g.id);
        // One source of truth for the route, so the button's label + handler
        // can never drift apart into a dead tap.
        final subjectRoute = (s == null || s.groupId == null)
            ? null
            : '/groups/${s.groupId}/students/${s.id}';
        return _PeekScaffold(
          entity: entity,
          title: name,
          avatar: PersonAvatar(name: name, radius: 26),
          facts: [if (group != null) 'In ${group.name}'],
          openLabel: subjectRoute == null ? null : 'Open full profile',
          onOpen: subjectRoute == null ? null : () => onOpen(subjectRoute),
        );

      case EntityKind.member:
        final m = _byId(
          ref.watch(membersInSpaceProvider).value ?? const <Member>[],
          entity.id,
          (x) => x.id,
        );
        final name = m?.displayName ?? entity.label;
        return _PeekScaffold(
          entity: entity,
          title: name,
          avatar: PersonAvatar(name: name, radius: 26),
          facts: const [],
          openLabel: m == null ? null : 'Open teammate',
          onOpen: m == null ? null : () => onOpen('/settings/team/${m.id}'),
        );

      case EntityKind.group:
        final g = _byId(
          ref.watch(groupsProvider).value ?? const <Group>[],
          entity.id,
          (x) => x.id,
        );
        return _PeekScaffold(
          entity: entity,
          title: g?.name ?? entity.label,
          facts: const [],
          openLabel: 'Open cohort',
          onOpen: () => onOpen('/groups/${entity.id}'),
        );

      case EntityKind.activity:
        final a = _byId(
          ref.watch(activitiesProvider).value ?? const <Activity>[],
          entity.id,
          (x) => x.id,
        );
        return _PeekScaffold(
          entity: entity,
          title: a?.name ?? entity.label,
          facts: [
            if (a?.description != null && a!.description!.trim().isNotEmpty)
              a.description!.trim(),
          ],
          openLabel: 'Open activity',
          onOpen: () => onOpen('/activities/${entity.id}'),
        );

      case EntityKind.location:
        final l = _byId(
          ref.watch(locationsProvider).value ?? const <Location>[],
          entity.id,
          (x) => x.id,
        );
        return _PeekScaffold(
          entity: entity,
          title: l?.name ?? entity.label,
          facts: const [],
          openLabel: 'Open places',
          onOpen: () => onOpen('/settings/locations'),
        );

      case EntityKind.vehicle:
        final v = _byId(
          ref.watch(vehiclesProvider).value ?? const <Vehicle>[],
          entity.id,
          (x) => x.id,
        );
        return _PeekScaffold(
          entity: entity,
          title: v?.name ?? entity.label,
          facts: const [],
          openLabel: v == null ? null : 'Open vehicle',
          onOpen: v == null ? null : () => onOpen('/vehicles/${v.id}'),
        );

      case EntityKind.role:
        RoleCard? card;
        for (final deck in roleDecks) {
          card = _byId(deck.cards, entity.id, (c) => c.fingerprint);
          if (card != null) break;
        }
        return _PeekScaffold(
          entity: entity,
          title: card?.name ?? entity.label,
          emoji: card?.emoji,
          facts: [
            if (card != null) 'Practises: ${card.habits.join(' · ')}',
            if (card != null) 'Builds ${card.builds}',
          ],
        );

      case EntityKind.world:
        final w = _byId(
          ref.watch(curriculumWorldsProvider).value ?? const <CurriculumWorld>[],
          entity.id,
          (x) => x.id,
        );
        return _PeekScaffold(
          entity: entity,
          title: w?.name ?? entity.label,
          emoji: w?.emoji,
          facts: const [],
          openLabel: 'Open world',
          onOpen: () => onOpen('/present-world/${entity.id}'),
        );

      case EntityKind.verb:
        final v = _byId(kVerbs, entity.id, (x) => x.id);
        return _PeekScaffold(
          entity: entity,
          title: v?.label ?? entity.label,
          emoji: v?.emoji,
          facts: const ['An action word kids pick to live for the day.'],
        );
    }
  }
}

/// The shared peek layout — drag handle, identity header, fact rows, and an
/// optional "open full" button. Every kind funnels through it so all peeks
/// read as one system.
class _PeekScaffold extends StatelessWidget {
  const _PeekScaffold({
    required this.entity,
    required this.title,
    required this.facts,
    this.avatar,
    this.emoji,
    this.openLabel,
    this.onOpen,
  });

  final EntityRef entity;
  final String title;
  final List<String> facts;
  final Widget? avatar;
  final String? emoji;
  final String? openLabel;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = entity.kind.accent;
    final tint = readableEntityTint(accent, theme.brightness);
    final fill = entityChipFill(accent, theme.brightness);

    final lead = avatar ??
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: emoji != null
              ? Text(emoji!, style: const TextStyle(fontSize: 26))
              : Icon(entity.kind.icon, color: tint, size: 26),
        );

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GlassDragHandle(bottomMargin: 14),
              Row(
                children: [
                  lead,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          entity.kind.noun.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tint,
                            letterSpacing: 0.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final f in facts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 9),
                          child: Icon(Icons.circle, size: 6, color: tint),
                        ),
                        Expanded(
                          child: Text(f, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
              if (openLabel != null && onOpen != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(openLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
