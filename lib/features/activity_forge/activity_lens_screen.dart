import 'dart:async';

import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/lens` — **any activity, the Different World way.** The app isn't a library
/// you must use; it's a lens you lay over whatever you're already doing. Type
/// the activity (a craft, a walk, snack, a board game) and see the twelve verbs
/// as twelve ways to do it — each kid does it through their three picks, so one
/// activity becomes twelve. Whatever you're doing already has twelve doors.
class ActivityLensScreen extends ConsumerStatefulWidget {
  const ActivityLensScreen({super.key});

  @override
  ConsumerState<ActivityLensScreen> createState() => _ActivityLensScreenState();
}

class _ActivityLensScreenState extends ConsumerState<ActivityLensScreen> {
  final _activity = TextEditingController();

  @override
  void dispose() {
    _activity.dispose();
    super.dispose();
  }

  void _keep() {
    final text = _activity.text.trim();
    if (text.isEmpty) return;
    unawaited(
      ref.read(entryActionsProvider).keepForgedActivity(instruction: text),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kept — find it in the forge.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activity = _activity.text.trim();
    return EdgeScaffold(
      body: ResponsivePage(
        children: [
          const ContentHeader(
            title: 'Any activity',
            subtitle: "Whatever you're doing already has twelve doors",
          ),
          TextField(
            controller: _activity,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'What are you doing?',
              hintText: 'making paper boats',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            activity.isEmpty
                ? 'Twelve ways one activity becomes twelve'
                : '"$activity" — twelve ways',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final v in kVerbs) _LensRow(verb: v),
          const SizedBox(height: 16),
          Text(
            'Each kid does it through THEIR three picks — so the same craft '
            'is a dozen different activities in one room. Name the concept it '
            'secretly teaches, ask "where else does this happen?", and you\'ve '
            'turned a craft into thinking.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          if (activity.isNotEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _keep,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Keep this activity'),
                  ),
                  // Run it through the play → name → bridge → question arc,
                  // full-screen, as a castable prompt the room can see.
                  FilledButton.icon(
                    onPressed: () => context.push('/arc', extra: activity),
                    icon: const Icon(Icons.slideshow_outlined),
                    label: const Text('Present this →'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Present plays it on rails — do it, name it, bridge it, '
                'ask it — so you teach the arc without holding it in your head.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LensRow extends StatelessWidget {
  const _LensRow({required this.verb});
  final Verb verb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(verb.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verb.label.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  verb.lens,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
