import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/schedule/day_template.dart';
import 'package:differentworld/features/schedule/day_template_providers.dart';
import 'package:differentworld/features/schedule/widgets/apply_day_template_sheet.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/shared/widgets/bento_grid.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
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
///
/// Two layouts over the SAME template list: the flush-left list (default)
/// and a BENTO grid (opt-in via the global "Bento everywhere" switch) that
/// re-lays each template as a compact card — 2-up on a phone — over the same
/// provider data.
class DayTemplatesScreen extends ConsumerWidget {
  const DayTemplatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Guard the SCREEN, not just the button. Every one of these was
    // reachable by deep link and by search with no check at all, so
    // hiding the entry point was never the same as gating the action.
    if (!ref.watch(viewerProvider).canManageSchedule) {
      return const EdgeScaffold(
        backFallbackRoute: '/schedule',
        body: NoAccess(
          title: 'You can’t edit day shapes yet.',
          message:
              'Day templates apply to the whole program. Ask whoever runs the schedule.',
        ),
      );
    }
    final templates = ref.watch(dayTemplatesProvider);
    final spaceId = ref.watch(viewerProvider).spaceId;
    // Part of the "Bento everywhere" sweep — gated ONLY on the global switch
    // (no per-screen toggle). When on, the template list re-lays as a dense
    // 2-up grid over the SAME provider data; off keeps the flush-left list.
    final bento = bentoEnabled(ref, perScreen: null);

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
              message:
                  'Build the shape of your day once — blocks you can '
                  'drag to reorder — then drop it onto any day. Teachers '
                  'fill in the details.',
              action: FilledButton.icon(
                onPressed: () => _create(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Build a day template'),
              ),
            )
          : bento
          ? _bentoBody(context, templates, spaceId)
          : _flatBody(context, templates, spaceId),
    );
  }

  /// The default layout — the flush-left list of full-width template rows.
  Widget _flatBody(
    BuildContext context,
    List<DayTemplate> templates,
    String? spaceId,
  ) {
    return ResponsivePage(
      children: [
        const ContentHeader(
          title: 'Day templates',
          subtitle: 'The shapes of your day — drop one onto a date',
        ),
        for (final t in templates) _TemplateCard(template: t, spaceId: spaceId),
      ],
    );
  }

  /// The bento variant — SAME templates, re-laid as compact cards in a
  /// responsive grid. The header stays full-width; each template is an
  /// equal-weight tile (`phone: 1` so they pack 2-up on a phone, more across
  /// wider screens). Each tile bounds a `_TemplateBentoCard` in a
  /// text-scale-aware height so the unbounded bento cell never throws.
  Widget _bentoBody(
    BuildContext context,
    List<DayTemplate> templates,
    String? spaceId,
  ) {
    final tileHeight = 132 + 56 * _textScale(context);
    return ResponsivePage(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ContentHeader(
            title: 'Day templates',
            subtitle: 'The shapes of your day — drop one onto a date',
          ),
        ),
        const SizedBox(height: 12),
        BentoGrid(
          tiles: [
            for (final t in templates)
              BentoTile(
                id: 'day-template-${t.id}',
                span: const BentoSpan(phone: 1),
                child: SizedBox(
                  height: tileHeight,
                  child: _TemplateBentoCard(template: t, spaceId: spaceId),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final viewer = ref.read(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) return;
    final router = GoRouter.of(context);
    final id = await ref
        .read(dayTemplateActionsProvider)
        .createTemplate(
          spaceId: spaceId,
          name: 'Regular day',
        );
    unawaited(router.push('/schedule/day-templates/$id'));
  }
}

/// The day-template fill summary ("filled" / "45m free" / "30m over") and
/// whether it's overfilled — shared by both layouts so the at-a-glance read
/// is identical in the list and the grid.
({String fill, bool overfilled}) _fillFor(DayTemplate t) {
  final fill = t.isOverfilled
      ? '${durationLabel(-t.freeMinutes)} over'
      : t.freeMinutes == 0
      ? 'filled'
      : '${durationLabel(t.freeMinutes)} free';
  return (fill: fill, overfilled: t.isOverfilled);
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, this.spaceId});
  final DayTemplate template;
  final String? spaceId;

  @override
  Widget build(BuildContext context) {
    final blockCount = template.blocks.length;
    final f = _fillFor(template);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FeatureCard(
        leading: const Icon(Icons.view_timeline_outlined),
        title: template.name,
        subtitle:
            '$blockCount ${blockCount == 1 ? "block" : "blocks"} · '
            '${clockLabel(template.startMinute)}–'
            '${clockLabel(template.endMinute)} · ${f.fill}',
        tone: f.overfilled ? FeatureCardTone.danger : FeatureCardTone.neutral,
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

/// The compact card for the bento grid — the SAME template, stacked to fit a
/// narrow 2-up cell: name + block/time summary on top, the Apply action (or a
/// chevron) at the bottom. Same taps as [_TemplateCard]: tap the card to edit,
/// tap Apply to drop it onto a date. `mainAxisSize.min` + a fixed gap (no
/// `Spacer`) keeps it safe inside the unbounded-height bento cell.
class _TemplateBentoCard extends StatelessWidget {
  const _TemplateBentoCard({required this.template, this.spaceId});
  final DayTemplate template;
  final String? spaceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final blockCount = template.blocks.length;
    final f = _fillFor(template);
    final canApply = spaceId != null && template.blocks.isNotEmpty;

    final bg = f.overfilled
        ? scheme.errorContainer.withValues(alpha: 0.45)
        : scheme.surfaceContainerHighest;
    final fg = f.overfilled ? scheme.onErrorContainer : scheme.onSurface;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: () => context.push('/schedule/day-templates/${template.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.view_timeline_outlined, size: 20, color: fg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        template.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$blockCount ${blockCount == 1 ? "block" : "blocks"}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: 0.78),
                  ),
                ),
                Text(
                  '${clockLabel(template.startMinute)}–'
                  '${clockLabel(template.endMinute)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: 0.78),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  f.fill,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: fg.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 10),
                if (canApply)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: () => showApplyDayTemplateSheet(
                        context,
                        template: template,
                        spaceId: spaceId!,
                      ),
                      icon: const Icon(Icons.event_available, size: 18),
                      label: const Text('Apply'),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerRight,
                    child: Icon(
                      Icons.chevron_right,
                      color: fg.withValues(alpha: 0.6),
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

/// Title-text-relative scale (1.0 = OS default) so cells grow with the
/// user's text-size setting instead of clipping at a fixed height.
double _textScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) / 14;
