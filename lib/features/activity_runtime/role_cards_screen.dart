import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/features/activity_runtime/role_capture.dart';
import 'package:differentworld/features/activity_runtime/roles.dart';
import 'package:differentworld/features/live_session/slide_present.dart';
import 'package:differentworld/shared/widgets/accent_card_tile.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/activity/roles` — the animal & nature ROLE CARDS deck
/// (docs/ROLES_SMART_PRACTICE.md). Browse the catalog; tap a card to flip to
/// its face — the three daily HABITS ("Today I am a Bee — I gather, I point
/// the way, I stay busy"), the three ARTIFACTS to leave behind, and the
/// trait it builds.
///
/// Slice 1: a browsable, glanceable catalog — the deck IS the catalog, the
/// phone IS the card. Next slices: the immersive "Today I am ___" pick that
/// records a habit-mark per habit, the printable card (the PDF path), and
/// artifact capture into the showcase.
class RoleCardsScreen extends StatefulWidget {
  const RoleCardsScreen({this.subject, super.key});

  /// When set (opened via "Practice a role" from a child's world), every
  /// artifact tool captures STRAIGHT to this child — no "which child?" prompt.
  /// Null = browsing the catalog; tools nudge to open from a child instead.
  final RoleSubject? subject;

  @override
  State<RoleCardsScreen> createState() => _RoleCardsScreenState();
}

class _RoleCardsScreenState extends State<RoleCardsScreen> {
  // A calm palette, cycled by index so neighbours never clash.
  static const _palette = <Color>[
    ActivityPalette.green, // leaf green
    ActivityPalette.blue, // sky
    ActivityPalette.amber, // amber
    ActivityPalette.teal, // teal
    ActivityPalette.purple, // orchid
    ActivityPalette.brown, // bark
    ActivityPalette.pink, // bloom
    ActivityPalette.indigo, // dusk
  ];

  int _deckIndex = 0;

  void _open(BuildContext context, RoleCard role) {
    unawaited(
      showGlassSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RoleCardFace(role: role, subject: widget.subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deck = roleDecks[_deckIndex];
    return EdgeScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ContentHeader(
                title: 'Role Cards',
                subtitle: deck.tagline,
              ),
            ),
            if (roleDecks.length > 1)
              _DeckSwitcher(
                decks: roleDecks,
                selected: _deckIndex,
                onSelect: (i) => setState(() => _deckIndex = i),
              ),
            Padding(
              // Bottom 96 clears the floating omnibox bar (~76) so the last
              // grid row isn't hidden behind it (rubric A3).
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  // Cell grows with text scale (smaller cells than the other
                  // decks) so name + "builds …" never clip.
                  mainAxisExtent: 120 + 64 * (MediaQuery.textScalerOf(context).scale(14) / 14),
                ),
                children: [
                  for (var i = 0; i < deck.cards.length; i++)
                    AccentCardTile(
                      color: _palette[i % _palette.length],
                      emoji: deck.cards[i].emoji,
                      title: deck.cards[i].name,
                      tagline: 'builds ${deck.cards[i].builds}',
                      semanticLabel:
                          'Role: ${deck.cards[i].name}, builds ${deck.cards[i].builds}',
                      onTap: () => _open(context, deck.cards[i]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A horizontally-scrolling row of deck chips ("Animals & Nature",
/// "People & Jobs", …). Scales as new theme decks land.
class _DeckSwitcher extends StatelessWidget {
  const _DeckSwitcher({
    required this.decks,
    required this.selected,
    required this.onSelect,
  });

  final List<RoleDeck> decks;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48, // M3 min tap target — chips were clipped to 44 (rubric E1)
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: decks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final deck = decks[i];
          return ChoiceChip(
            label: Text('${deck.emoji}  ${deck.name}'),
            selected: i == selected,
            showCheckmark: false,
            onSelected: (_) => onSelect(i),
          );
        },
      ),
    );
  }
}


/// The full face of one role card — reused by the browse sheet now, and
/// (next slices) the immersive "Today I am ___" pick + the printable PDF.
class _RoleCardFace extends StatelessWidget {
  const _RoleCardFace({required this.role, this.subject});

  final RoleCard role;

  /// The child being practised for, if opened from their world. Threaded into
  /// each artifact tool so a tap captures straight to them.
  final RoleSubject? subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(role.emoji, style: const TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 8),
            Text(
              'Today I am ${role.article} ${role.name}',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Chip(
                label: Text('builds ${role.builds}'),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 20),
            _SectionLabel(label: 'My 3 habits', color: muted),
            const SizedBox(height: 8),
            for (final habit in role.habits)
              _Line(
                icon: Icons.radio_button_unchecked,
                iconColor: theme.colorScheme.primary,
                text: 'I $habit',
                strong: true,
              ),
            const SizedBox(height: 18),
            _SectionLabel(
              label: subject == null
                  ? 'Make these — the proof'
                  : 'Make these — tap to capture for ${subject!.subjectName}',
              color: muted,
            ),
            const SizedBox(height: 8),
            // Each artifact is a TOOL: one tap → its OWN immediate surface
            // (camera / on-screen canvas / a quick note), never a generic form.
            // The role's own words pick the tool; with a child in context the
            // capture lands straight in their cumulative work. docs/VISION.md
            // 2026-06-20 — every role ships the tools to practise it.
            for (final artifact in role.artifacts)
              _ArtifactTool(artifact: artifact, subject: subject),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => unawaited(
                presentSlides(
                  context,
                  title: role.name,
                  slides: [
                    PresentSlide(
                      eyebrow: 'TODAY WE ARE',
                      title: '${role.article} ${role.name}',
                      emoji: role.emoji,
                      subtitle: 'we build ${role.builds}',
                    ),
                    for (final habit in role.habits)
                      PresentSlide(
                        eyebrow: 'A ${role.name.toUpperCase()} HABIT',
                        title: 'I $habit',
                        icon: Icons.bolt,
                      ),
                  ],
                ),
              ),
              icon: const Icon(Icons.cast),
              label: const Text('Cast this role to the room'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One artifact as a tappable TOOL. The verb in the artifact text picks the
/// modality (`roleToolFor` — the single source of truth shared with the
/// capture action): Draw → on-screen canvas, Snap → camera, Note → a quick
/// typed note. With a [subject] in context, ONE tap runs that immediate
/// surface and saves straight to the child's cumulative work — no form, no
/// extra presses. Without one (catalog browse), the tap nudges to open the
/// role from a child's world.
class _ArtifactTool extends ConsumerWidget {
  const _ArtifactTool({required this.artifact, this.subject});

  final String artifact;
  final RoleSubject? subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tool = roleToolFor(artifact);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final s = subject;
            if (s == null) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Open this role from a child’s world to capture.',
                  ),
                ),
              );
              return;
            }
            unawaited(
              captureRoleArtifact(context, ref, subject: s, artifact: artifact),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(tool.icon, size: 20, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(artifact, style: theme.textTheme.bodyLarge),
                ),
                Text(
                  '${tool.label} ›',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      semanticsLabel: label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        fontSize: 12,
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.strong,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
