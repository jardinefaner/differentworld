import 'dart:async';

import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/activity_forge/activity_forge.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `/forge` — **make an activity.** The generative formula made tappable:
/// verb × noun × constraint × time. Lock a verb to what you're teaching (or
/// leave it on Any), then roll. The point you can feel: it never runs out.
class ActivityForgeScreen extends StatefulWidget {
  const ActivityForgeScreen({super.key});

  @override
  State<ActivityForgeScreen> createState() => _ActivityForgeScreenState();
}

class _ActivityForgeScreenState extends State<ActivityForgeScreen> {
  // Start somewhere varied so the first roll differs per open; then walk the
  // odometer one step at a time.
  int _seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  String? _verbId;

  void _roll() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _seed = (_seed + 1) & 0x7fffffff);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final forged = forgeActivity(_seed, verbId: _verbId);
    return EdgeScaffold(
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Make an activity',
            subtitle: 'Verb × noun × constraint × time — a formula, not a list',
          ),
          // Lock the verb (to what you're teaching) or leave it on Any.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Any verb'),
                selected: _verbId == null,
                onSelected: (_) => setState(() => _verbId = null),
              ),
              for (final v in kVerbs)
                ChoiceChip(
                  label: Text('${v.emoji} ${v.label}'),
                  selected: _verbId == v.id,
                  onSelected: (_) => setState(() => _verbId = v.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ForgedCard(forged: forged),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _roll,
              icon: const Icon(Icons.casino_outlined),
              label: const Text('Roll again'),
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
