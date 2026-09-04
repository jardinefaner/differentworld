import 'dart:async';

import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
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
///
/// Two layouts over the SAME twelve verbs: the flush-left list of lens rows
/// (default) and a BENTO grid (opt-in via the global "Bento everywhere"
/// switch) that re-lays the twelve as compact cards — 2-up on a phone. The
/// input + framing copy stay full-width either way.
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
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the twelve verbs re-lay as a dense
    // 2-up grid; off keeps the existing flush-left lens rows. Same verbs.
    final bento = bentoEnabled(ref, perScreen: null);
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
          if (bento)
            // The twelve verbs as compact 2-up cards (≈180dp cells on phone,
            // more across wider screens). A small bounded set, so a
            // shrink-wrapped grid inside the page scroll is fine — the builder
            // still constructs cells on demand. Cells grow with text scale.
            GridView.builder(
              shrinkWrap: true,
              primary: false,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 96 + 28 * _textScale(context),
              ),
              itemCount: kVerbs.length,
              itemBuilder: (context, i) => _LensCard(
                key: ValueKey('lens-${kVerbs[i].id}'),
                verb: kVerbs[i],
              ),
            )
          else
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
                  verb.label,
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

/// The compact card for the bento grid — the SAME verb (emoji + label + lens),
/// stacked to fit a narrow 2-up cell. No interaction (the lens rows are
/// reference content, not tappable), so it's a plain tinted surface.
/// `mainAxisSize.min` + a fixed gap keeps it safe inside the grid cell.
class _LensCard extends StatelessWidget {
  const _LensCard({required this.verb, super.key});
  final Verb verb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(verb.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  verb.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Flexible(
            child: Text(
              verb.lens,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Title-text-relative scale (1.0 = OS default) so cells grow with the
/// user's text-size setting instead of clipping at a fixed height.
double _textScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14;
