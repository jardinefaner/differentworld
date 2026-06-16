import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/schedule/day_template.dart';
import 'package:differentworld/features/schedule/day_template_providers.dart';
import 'package:differentworld/features/schedule/widgets/apply_day_template_sheet.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/schedule/day-templates` — the director's **day-template library**. A
/// day template is the *shape of the day*: an ordered list of
/// duration-blocks (set the start + end once, drag blocks to reorder, the
/// clock times recompute). Keep a few — "Regular day", "Field-trip day" —
/// and drop one onto any date to generate the schedule; teachers fill in
/// the activity / note / lead per block.
class DayTemplatesScreen extends ConsumerWidget {
  const DayTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(dayTemplatesProvider);
    final spaceId = ref.watch(viewerProvider).spaceId;

    return EdgeScaffold(
      backFallbackRoute: '/schedule',
      actions: [
        PrimaryActionButton(
          tooltip: 'New day template',
          icon: Icons.add,
          onPressed: () => _create(context, ref),
        ),
      ],
      body: templates.isEmpty
          ? EmptyState(
              icon: Icons.view_timeline_outlined,
              title: 'No day templates yet',
              message: 'Build the shape of your day once — blocks you can '
                  'drag to reorder — then drop it onto any day. Teachers '
                  'fill in the details.',
              action: FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Build a day template'),
              ),
            )
          : ResponsivePage(
              children: [
                const ContentHeader(
                  title: 'Day templates',
                  subtitle: 'The shapes of your day — drop one onto a date',
                ),
                for (final t in templates)
                  _TemplateCard(template: t, spaceId: spaceId),
              ],
            ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final viewer = ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) return;
    final router = GoRouter.of(context);
    final id = await ref.read(dayTemplateActionsProvider).createTemplate(
          spaceId: spaceId,
          name: 'Regular day',
        );
    unawaited(router.push('/schedule/day-templates/$id'));
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, this.spaceId});
  final DayTemplate template;
  final String? spaceId;

  @override
  Widget build(BuildContext context) {
    final blockCount = template.blocks.length;
    final fill = template.isOverfilled
        ? '${durationLabel(-template.freeMinutes)} over'
        : template.freeMinutes == 0
            ? 'filled'
            : '${durationLabel(template.freeMinutes)} free';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FeatureCard(
        leading: const Icon(Icons.view_timeline_outlined),
        title: template.name,
        subtitle: '$blockCount ${blockCount == 1 ? "block" : "blocks"} · '
            '${clockLabel(template.startMinute)}–'
            '${clockLabel(template.endMinute)} · $fill',
        tone: template.isOverfilled
            ? FeatureCardTone.danger
            : FeatureCardTone.neutral,
        // The connection that makes a template usable: apply it to a day
        // straight from the list — no editor drill. Tapping the card still
        // opens the editor to reshape it.
        trailing: (spaceId == null || template.blocks.isEmpty)
            ? const Icon(Icons.chevron_right)
            : FilledButton.tonalIcon(
                onPressed: () => showApplyDayTemplateSheet(
                  context,
                  template: template,
                  spaceId: spaceId!,
                ),
                icon: const Icon(Icons.event_available, size: 18),
                label: const Text('Apply'),
              ),
        onTap: () => context.push('/schedule/day-templates/${template.id}'),
      ),
    );
  }
}
