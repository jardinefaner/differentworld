import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/missions/mission_templates.dart';
import 'package:differentworld/features/missions/missions_providers.dart';
import 'package:differentworld/shared/error_handling.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/settings/missions` — the program's mission catalog (docs/MISSIONS.md):
/// real jobs with a manual + a checklist + the evidence they leave. The
/// grounded counterpart to Role Cards. Maintain it once; slice 2 lets a kid
/// claim one, work the checklist, and bank real evidence. Reached via the
/// omnibox ("missions" / "jobs"), matching the other library surfaces.
class MissionsListScreen extends ConsumerWidget {
  const MissionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsAsync = ref.watch(missionsProvider);
    final canEdit = ref.watch(viewerProvider).canManageSpace;
    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: [
        if (canEdit)
          PrimaryActionButton(
            tooltip: 'New mission',
            icon: Icons.add,
            onPressed: () => _openEdit(context),
          ),
      ],
      body: missionsAsync.when(
        loading: () => const LoadingSlot(),
        error: (_, _) => ErrorState(
          title: 'Could not load missions',
          onRetry: () => ref.invalidate(missionsProvider),
        ),
        data: (missions) {
          if (missions.isEmpty) {
            return EmptyState(
              icon: Icons.flag_outlined,
              title: 'No missions yet',
              message:
                  'Missions are real jobs kids can take on — Equipment '
                  'Manager, Snack Helper, Cleanup Crew — each with a manual '
                  'and a checklist. Start from the ready-made set, then make '
                  'them yours.',
              action: canEdit
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _addStarter(context, ref),
                          icon: const Icon(Icons.auto_awesome),
                          label: Text(
                            'Add the starter set '
                            '(${missionTemplates.length})',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _openEdit(context),
                          child: const Text('Add your own instead'),
                        ),
                      ],
                    )
                  : null,
            );
          }
          return ResponsivePage.builder(
            itemCount: missions.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Missions',
                    subtitle: 'Real jobs kids can take on',
                    bottomGap: 8,
                  ),
                );
              }
              return _MissionTile(mission: missions[i - 1]);
            },
          );
        },
      ),
    );
  }
}

Future<void> _addStarter(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await runReported(
    library: 'missions',
    messenger: messenger,
    onError: 'Could not add the starter missions.',
    action: () => ref.read(missionActionsProvider).addStarterSet(),
  );
}

String missionAgeLabel(Mission m) {
  final lo = m.minAge;
  final hi = m.maxAge;
  if (lo == null && hi == null) return 'Any age';
  if (lo != null && hi != null) return 'Ages $lo–$hi';
  if (lo != null) return 'Ages $lo+';
  return 'Up to $hi';
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final builds = mission.builds;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: Text(
          mission.icon ?? '🎯',
          style: const TextStyle(fontSize: 22),
        ),
      ),
      title: Text(mission.name),
      subtitle: mission.tagline == null || mission.tagline!.isEmpty
          ? Text(missionAgeLabel(mission))
          : Text('${mission.tagline} · ${missionAgeLabel(mission)}'),
      trailing: builds == null || builds.isEmpty
          ? const Icon(Icons.chevron_right)
          : Chip(
              label: Text(builds),
              visualDensity: VisualDensity.compact,
              side: BorderSide.none,
              backgroundColor: theme.colorScheme.secondaryContainer,
              labelStyle: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
      onTap: () => _openDetail(context, mission),
    );
  }
}

// ── Detail (the "what they look like" view) ────────────────────────────
Future<void> _openDetail(BuildContext context, Mission mission) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MissionDetailSheet(mission: mission),
  );
}

class _MissionDetailSheet extends ConsumerWidget {
  const _MissionDetailSheet({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final canEdit = ref.watch(viewerProvider).canManageSpace;
    final actions = decodeMissionActions(mission.actions);
    final evidence = MissionEvidenceKind.fromKey(mission.evidenceKind);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                mission.icon ?? '🎯',
                style: const TextStyle(fontSize: 56),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mission.name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                if (mission.builds != null && mission.builds!.isNotEmpty)
                  Chip(
                    label: Text('builds ${mission.builds}'),
                    visualDensity: VisualDensity.compact,
                  ),
                Chip(
                  label: Text(missionAgeLabel(mission)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (mission.why != null && mission.why!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                mission.why!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (mission.rules != null && mission.rules!.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionLabel('The manual', muted),
              const SizedBox(height: 6),
              Text(mission.rules!, style: theme.textTheme.bodyLarge),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionLabel('Steps to practice', muted),
              const SizedBox(height: 8),
              for (var i = 0; i < actions.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          actions[i],
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 20),
            _SectionLabel('Leave behind', muted),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(evidence.icon, size: 20, color: muted),
                const SizedBox(width: 8),
                Text(evidence.label, style: theme.textTheme.bodyLarge),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  unawaited(_openEdit(context, existing: mission));
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit this mission'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        fontSize: 12,
      ),
    );
  }
}

// ── Edit ───────────────────────────────────────────────────────────────
Future<void> _openEdit(BuildContext context, {Mission? existing}) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MissionEditSheet(existing: existing),
  );
}

class _MissionEditSheet extends ConsumerStatefulWidget {
  const _MissionEditSheet({this.existing});

  final Mission? existing;

  @override
  ConsumerState<_MissionEditSheet> createState() => _MissionEditSheetState();
}

class _MissionEditSheetState extends ConsumerState<_MissionEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _icon;
  late final TextEditingController _tagline;
  late final TextEditingController _why;
  late final TextEditingController _builds;
  late final TextEditingController _rules;
  late final TextEditingController _actions; // one step per line
  late final TextEditingController _minAge;
  late final TextEditingController _maxAge;
  late MissionEvidenceKind _evidence;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _icon = TextEditingController(text: e?.icon ?? '');
    _tagline = TextEditingController(text: e?.tagline ?? '');
    _why = TextEditingController(text: e?.why ?? '');
    _builds = TextEditingController(text: e?.builds ?? '');
    _rules = TextEditingController(text: e?.rules ?? '');
    _actions = TextEditingController(
      text: decodeMissionActions(e?.actions).join('\n'),
    );
    _minAge = TextEditingController(
      text: e?.minAge == null ? '' : e!.minAge.toString(),
    );
    _maxAge = TextEditingController(
      text: e?.maxAge == null ? '' : e!.maxAge.toString(),
    );
    _evidence = MissionEvidenceKind.fromKey(e?.evidenceKind);
  }

  @override
  void dispose() {
    _name.dispose();
    _icon.dispose();
    _tagline.dispose();
    _why.dispose();
    _builds.dispose();
    _rules.dispose();
    _actions.dispose();
    _minAge.dispose();
    _maxAge.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    setState(() => _saving = true);
    final actions = ref.read(missionActionsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final existingId = widget.existing?.id;
    String? trimOrNull(TextEditingController c) {
      final t = c.text.trim();
      return t.isEmpty ? null : t;
    }

    final steps = _actions.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final minAge = int.tryParse(_minAge.text.trim());
    final maxAge = int.tryParse(_maxAge.text.trim());
    final ok = await runReported(
      library: 'missions',
      messenger: messenger,
      onError: 'Could not save the mission.',
      action: () async {
        if (existingId == null) {
          await actions.create(
            name: n,
            icon: trimOrNull(_icon),
            tagline: trimOrNull(_tagline),
            why: trimOrNull(_why),
            builds: trimOrNull(_builds),
            rules: trimOrNull(_rules),
            actions: steps,
            evidence: _evidence,
            minAge: minAge,
            maxAge: maxAge,
          );
        } else {
          await actions.update_(
            id: existingId,
            name: n,
            icon: trimOrNull(_icon),
            tagline: trimOrNull(_tagline),
            why: trimOrNull(_why),
            builds: trimOrNull(_builds),
            rules: trimOrNull(_rules),
            actions: steps,
            evidence: _evidence,
            minAge: minAge,
            maxAge: maxAge,
          );
        }
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) navigator.pop();
  }

  Future<void> _delete() async {
    final existingId = widget.existing?.id;
    if (existingId == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this mission?'),
        content: const Text('It disappears from the catalog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    await ref.read(missionActionsProvider).delete_(existingId);
    if (mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.of(context).viewInsets;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + insets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'New mission' : 'Edit mission',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _icon,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Icon',
                      hintText: '🏀',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: widget.existing == null,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Equipment Manager',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Tagline (optional)',
                hintText: 'Gear in, gear out, all accounted for',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _builds,
                    decoration: const InputDecoration(
                      labelText: 'Builds (a trait)',
                      hintText: 'responsibility',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _minAge,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min age',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _maxAge,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max age',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _why,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Why it matters (optional)',
                hintText: 'Our gear lasts when someone looks after it.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rules,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'The manual — how, and where things go',
                hintText: 'Balls live in the bin by the gym door…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _actions,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Steps to practice — one per line',
                hintText: 'Hand the gear out fairly\nCount it back in\n…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('LEAVE BEHIND', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final k in MissionEvidenceKind.values)
                  ChoiceChip(
                    avatar: Icon(k.icon, size: 18),
                    label: Text(k.label),
                    selected: _evidence == k,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _evidence = k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
