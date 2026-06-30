import 'dart:async';

import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/action_words/block_run.dart';
import 'package:differentworld/features/action_words/routine_script_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/routines` — the **routine-script editor.** Pick an everyday routine
/// (arrival / meals / rest / …), edit its ordered steps + the tools to bring,
/// and save. The overrides are stored on the Space's caps, so they're shared
/// with the whole team and ride PowerSync; a routine you never touch keeps its
/// baked-in default. The day-run reads these as the highest-priority
/// `scriptOverride` (docs/VISION.md "every block carries its run-script").
///
/// Each routine's in-progress edits stay alive in memory while you switch
/// between routines, so flipping tabs never loses typed text (CLAUDE.md). One
/// Save commits the routine you're on.
class RoutineScriptEditorScreen extends ConsumerStatefulWidget {
  const RoutineScriptEditorScreen({super.key});

  @override
  ConsumerState<RoutineScriptEditorScreen> createState() =>
      _RoutineScriptEditorScreenState();
}

class _Draft {
  _Draft(this.steps, this.tools);
  List<TextEditingController> steps;
  List<String> tools;
}

class _RoutineScriptEditorScreenState
    extends ConsumerState<RoutineScriptEditorScreen> {
  RoutineKind _selected = RoutineKind.values.first;
  final Map<RoutineKind, _Draft> _drafts = {};
  final TextEditingController _toolCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Seed every routine's draft from its effective script (override or
    // default) once, so switching routines is just a selection change — typed
    // edits survive the switch.
    for (final r in RoutineKind.values) {
      _drafts[r] = _draftFrom(ref.read(effectiveRoutineScriptProvider(r)));
    }
  }

  _Draft _draftFrom(BlockRunScript s) => _Draft(
    [for (final step in s.steps) TextEditingController(text: step)],
    List<String>.of(s.tools),
  );

  @override
  void dispose() {
    for (final d in _drafts.values) {
      for (final c in d.steps) {
        c.dispose();
      }
    }
    _toolCtrl.dispose();
    super.dispose();
  }

  BlockRunScript _currentScript() {
    final d = _drafts[_selected]!;
    return (
      steps: [
        for (final c in d.steps)
          if (c.text.trim().isNotEmpty) c.text.trim(),
      ],
      tools: [
        for (final t in d.tools)
          if (t.trim().isNotEmpty) t.trim(),
      ],
    );
  }

  bool _dirty(RoutineKind r) {
    final eff = ref.read(effectiveRoutineScriptProvider(r));
    final d = _drafts[r]!;
    final steps = [
      for (final c in d.steps)
        if (c.text.trim().isNotEmpty) c.text.trim(),
    ];
    final tools = [
      for (final t in d.tools)
        if (t.trim().isNotEmpty) t.trim(),
    ];
    return !listEquals(steps, eff.steps) || !listEquals(tools, eff.tools);
  }

  bool get _anyDirty => RoutineKind.values.any(_dirty);

  Future<void> _save(String spaceId) async {
    if (_saving) return;
    final script = _currentScript();
    if (script.steps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A routine needs at least one step.')),
      );
      return;
    }
    // Capture the target BEFORE the await — the user can switch chips while the
    // write is in flight, and _selected is mutable state.
    final target = _selected;
    final label = target.label;
    setState(() => _saving = true);
    try {
      await ref
          .read(routineScriptActionsProvider)
          .setScript(spaceId: spaceId, routine: target, script: script);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label saved')),
      );
    } on Object catch (_) {
      // The write is optimistic-but-can-reject (RLS / schema). Surface it with
      // a retry instead of swallowing it; the local draft stays put.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't save $label"),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(_save(spaceId)),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetToDefault(String spaceId) async {
    if (_saving) return;
    // Capture the target before the await — _selected may change mid-flight.
    final target = _selected;
    setState(() => _saving = true);
    try {
      await ref
          .read(routineScriptActionsProvider)
          .resetScript(spaceId: spaceId, routine: target);
      if (!mounted) return;
      // Re-seed the target routine's draft from the baked-in default.
      final old = _drafts[target]!;
      for (final c in old.steps) {
        c.dispose();
      }
      setState(() {
        _drafts[target] = _draftFrom(defaultRoutineScript(target));
      });
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't reset ${target.label}")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addStep() {
    setState(() => _drafts[_selected]!.steps.add(TextEditingController()));
  }

  void _removeStep(int i) {
    setState(() {
      final d = _drafts[_selected]!;
      d.steps.removeAt(i).dispose();
    });
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    setState(() {
      final steps = _drafts[_selected]!.steps;
      var target = newIndex;
      if (target > oldIndex) target -= 1;
      target = target.clamp(0, steps.length - 1);
      final moved = steps.removeAt(oldIndex);
      steps.insert(target, moved);
    });
  }

  void _addTool() {
    final t = _toolCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _drafts[_selected]!.tools.add(t);
      _toolCtrl.clear();
    });
  }

  void _removeTool(int i) {
    setState(() => _drafts[_selected]!.tools.removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final spaceId = viewer.spaceId;
    if (spaceId == null) {
      return const EdgeScaffold(
        backFallbackRoute: '/settings',
        body: EmptyState(
          icon: Icons.tune,
          title: 'No program yet',
          message: 'Join or create a program to edit its routines.',
        ),
      );
    }
    // Editing a routine is a TEAM-WIDE write (it changes how every block runs,
    // for everyone), so it's gated to the day-authoring tier — directors + lead
    // teachers (canManageSchedule). Assistants / substitutes / guardians land
    // here read-only. The server policy is `using(true)` (the ES256 workaround),
    // so this UI gate is the real enforcement layer.
    if (!viewer.canManageSchedule) {
      return const EdgeScaffold(
        backFallbackRoute: '/settings',
        body: EmptyState(
          icon: Icons.lock_outline,
          title: 'Routines are set by your lead',
          message:
              'Your director or a lead teacher manages how the day’s routines '
              'run. Ask them if a step needs to change.',
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final draft = _drafts[_selected]!;
    final customized =
        ref.watch(customRoutineScriptProvider(_selected)) != null;

    return EdgeScaffold(
      backFallbackRoute: '/settings',
      actions: const [SyncStatusIndicator()],
      body: DismissGuard(
        isDirty: () => _anyDirty,
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                children: [
                  const ContentHeader(
                    title: 'Routine scripts',
                    subtitle:
                        'How your everyday blocks run — edit once, every day '
                        'uses it. Shared with your team.',
                  ),

                  // Routine picker — flipping tabs keeps each routine's edits.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in RoutineKind.values)
                        ChoiceChip(
                          key: ValueKey(r),
                          label: Text(r.label),
                          selected: r == _selected,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _selected = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Text(
                        'Steps',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: cs.onSurface),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'drag to reorder',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: draft.steps.length,
                    onReorder: _reorderSteps,
                    itemBuilder: (context, i) {
                      final ctrl = draft.steps[i];
                      return Padding(
                        key: ValueKey(ctrl),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            ReorderableDragStartListener(
                              index: i,
                              child: Semantics(
                                label: 'Drag to reorder',
                                child: SizedBox(
                                  width: 44,
                                  height: 48,
                                  child: Icon(
                                    Icons.drag_indicator,
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: TextField(
                                controller: ctrl,
                                textInputAction: TextInputAction.done,
                                minLines: 1,
                                maxLines: 3,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: 'Describe the step',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Remove step',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _removeStep(i),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addStep,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add step'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Bring',
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: 8),
                  // Each child carries a stable key so adding / removing a chip
                  // doesn't shift Flutter's position-based element matching onto
                  // the trailing TextField — which would tear down its
                  // TextInputConnection and close the IME mid-type (the
                  // "Stack children without keys" gotcha).
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (var i = 0; i < draft.tools.length; i++)
                        InputChip(
                          key: ValueKey('tool-${draft.tools[i]}-$i'),
                          label: Text(draft.tools[i]),
                          onDeleted: () => _removeTool(i),
                        ),
                      SizedBox(
                        key: const ValueKey('tools-input'),
                        width: 180,
                        child: TextField(
                          controller: _toolCtrl,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addTool(),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Add a tool…',
                            suffixIcon: IconButton(
                              tooltip: 'Add tool',
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: _addTool,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      if (customized)
                        TextButton(
                          key: const ValueKey('reset-btn'),
                          onPressed: _saving
                              ? null
                              : () => unawaited(_resetToDefault(spaceId)),
                          child: const Text('Reset to default'),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        key: const ValueKey('save-btn'),
                        onPressed: (_dirty(_selected) && !_saving)
                            ? () => unawaited(_save(spaceId))
                            : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check, size: 18),
                        label: Text('Save ${_selected.label}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
