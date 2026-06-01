import 'dart:async';

import 'package:differentworld/features/activity_runtime/roles.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';

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
  const RoleCardsScreen({super.key});

  @override
  State<RoleCardsScreen> createState() => _RoleCardsScreenState();
}

class _RoleCardsScreenState extends State<RoleCardsScreen> {
  // A calm palette, cycled by index so neighbours never clash.
  static const _palette = <Color>[
    Color(0xFF66BB6A), // leaf green
    Color(0xFF42A5F5), // sky
    Color(0xFFFFA726), // amber
    Color(0xFF26A69A), // teal
    Color(0xFFAB47BC), // orchid
    Color(0xFF8D6E63), // bark
    Color(0xFFEC407A), // bloom
    Color(0xFF5C6BC0), // dusk
  ];

  int _deckIndex = 0;

  void _open(BuildContext context, RoleCard role) {
    unawaited(
      showGlassSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _RoleCardFace(role: role),
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
              child: GridView.extent(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.82,
                children: [
                  for (var i = 0; i < deck.cards.length; i++)
                    _RoleTile(
                      role: deck.cards[i],
                      color: _palette[i % _palette.length],
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

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.role,
    required this.color,
    required this.onTap,
  });

  final RoleCard role;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // One clean announcement instead of three loose text fragments
    // (rubric E2).
    return Semantics(
      button: true,
      label: 'Role: ${role.name}, builds ${role.builds}',
      excludeSemantics: true,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role.emoji, style: const TextStyle(fontSize: 40)),
                const Spacer(),
                Text(
                  role.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'builds ${role.builds}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
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

/// The full face of one role card — reused by the browse sheet now, and
/// (next slices) the immersive "Today I am ___" pick + the printable PDF.
class _RoleCardFace extends StatelessWidget {
  const _RoleCardFace({required this.role});

  final RoleCard role;

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
            _SectionLabel(label: "I'll leave behind", color: muted),
            const SizedBox(height: 8),
            for (final artifact in role.artifacts)
              _Line(
                icon: Icons.auto_awesome_outlined,
                iconColor: muted,
                text: artifact,
                strong: false,
              ),
            const SizedBox(height: 18),
            Text(
              'Pick this role and practice the 3 habits today.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
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
