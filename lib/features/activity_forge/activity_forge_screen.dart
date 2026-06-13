import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/activity_forge/activity_forge.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/forge` — **make an activity.** The generative formula made tappable:
/// verb × noun × constraint × time. Lock a verb to what you're teaching, draw
/// the THINGS from this week's live world (or anything), then roll. The point
/// you can feel: it never runs out.
class ActivityForgeScreen extends ConsumerStatefulWidget {
  const ActivityForgeScreen({super.key});

  @override
  ConsumerState<ActivityForgeScreen> createState() =>
      _ActivityForgeScreenState();
}

class _ActivityForgeScreenState extends ConsumerState<ActivityForgeScreen> {
  // Start somewhere varied so the first roll differs per open; then walk the
  // odometer one step at a time.
  int _seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  String? _verbId;
  bool _useWorldNouns = true;

  void _roll() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _seed = (_seed + 1) & 0x7fffffff);
  }

  String _verbLabel() {
    if (_verbId == null) return 'Any verb';
    final v = kVerbs.where((v) => v.id == _verbId).firstOrNull;
    return v == null ? 'Any verb' : 'Verb: ${v.emoji} ${v.label}';
  }

  /// Pick (or clear) the locked verb in a sheet — replaces the 13-chip wall.
  Future<void> _pickVerb() async {
    await showGlassSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any verb'),
                selected: _verbId == null,
                onSelected: (_) {
                  setState(() => _verbId = null);
                  Navigator.of(sheetCtx).pop();
                },
              ),
              for (final v in kVerbs)
                ChoiceChip(
                  label: Text('${v.emoji} ${v.label}'),
                  selected: _verbId == v.id,
                  onSelected: (_) {
                    setState(() => _verbId = v.id);
                    Navigator.of(sheetCtx).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _keep(ForgedActivity forged) {
    unawaited(
      ref
          .read(entryActionsProvider)
          .keepForgedActivity(
            instruction: forged.instruction,
            verbId: forged.verb.id,
            noun: forged.noun,
            constraint: forged.constraint,
            minutes: forged.minutes,
          ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Kept')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final world = ref.watch(currentWorldProvider);
    final worldNouns = world == null ? null : kWorldNouns[world.id];
    final useWorld = _useWorldNouns && worldNouns != null;
    final forged = forgeActivity(
      _seed,
      verbId: _verbId,
      nouns: useWorld ? worldNouns : null,
    );
    final kept = ref.watch(keptActivitiesProvider).value ?? const <Entry>[];
    return EdgeScaffold(
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Make an activity',
            subtitle: 'Verb × noun × constraint × time — a formula, not a list',
          ),
          // The THINGS: this week's live world, or anything.
          if (worldNouns != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('${world!.emoji} ${world.name} things'),
                  selected: _useWorldNouns,
                  onSelected: (_) => setState(() => _useWorldNouns = true),
                ),
                ChoiceChip(
                  label: const Text('🌍 Anything'),
                  selected: !_useWorldNouns,
                  onSelected: (_) => setState(() => _useWorldNouns = false),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // Lock the verb to what you're teaching — ONE control, not a wall
          // of 13 chips (forge was 🔴, the chip wall buried the hero card —
          // docs/CLARITY_RUBRIC.md). Tap to pick; the forged card leads.
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              avatar: Icon(
                _verbId == null ? Icons.lock_open_outlined : Icons.lock_outline,
                size: 18,
              ),
              label: Text(_verbLabel()),
              onPressed: _pickVerb,
            ),
          ),
          const SizedBox(height: 16),
          _ForgedCard(forged: forged),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _keep(forged),
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Keep this one'),
                ),
                FilledButton.icon(
                  onPressed: _roll,
                  icon: const Icon(Icons.casino_outlined),
                  label: const Text('Roll again'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              '${ForgedActivity.space} activities from four short lists. '
              'A formula never runs out.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => context.push('/lens'),
              child: const Text('…or run your own activity →'),
            ),
          ),
          if (kept.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'KEPT',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in kept)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  title: Text(e.body ?? ''),
                  trailing: IconButton(
                    tooltip: 'Forget',
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => unawaited(
                      ref.read(entryActionsProvider).removeKeptActivity(e.id),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ForgedCard extends StatelessWidget {
  const _ForgedCard({required this.forged});
  final ForgedActivity forged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The instruction — the hero.
          Text(
            forged.instruction,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag('${forged.verb.emoji} ${forged.verb.label.toUpperCase()}'),
              _Tag('${forged.minutes} min'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Their way: ${forged.verb.lens}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
