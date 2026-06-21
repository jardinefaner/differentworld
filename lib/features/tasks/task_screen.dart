import 'dart:async';

import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/shared/format/date_keys.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Create a new task — body + optional due date.
///
/// Promoted from `task_sheet.dart` (bottom-sheet) to the
/// `/tasks/new` route in Wave 21. Same low-friction shape as
/// `CaptureScreen` but with one explicit Save (tasks aren't journal
/// jots; they need confirmation).
class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();
  DateTime? _due;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || _saving) return;
    setState(() => _saving = true);
    final actions = ref.read(taskActionsProvider);
    final goRouter = GoRouter.of(context);
    try {
      await actions.create(
        body: body,
        dueAt: _due?.toUtc().toIso8601String(),
      );
      if (!mounted) return;
      if (goRouter.canPop()) goRouter.pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'tasks'),
      );
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _due = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EdgeScaffold(
      backFallbackRoute: '/tasks',
      body: FormBody(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const ContentHeader(
            title: 'New task',
            subtitle: 'What needs doing?',
          ),
          // PRIMARY: the one thing this screen is for. Give it the size
          // and weight to lead — taller field, larger text — so the eye
          // lands here first and the secondary controls below recede.
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            autofocus: true,
            minLines: 4,
            maxLines: 10,
            style: theme.textTheme.titleMedium,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Describe the task…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          // A divider quiets everything below it: the one optional detail
          // (a due date) is demoted to a single muted chip, not a peer of
          // the title field. No functionality removed — just re-weighted.
          const Divider(height: 1),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _due == null
                ? OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: const Text('Add a due date'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                  )
                // Once a date is chosen it reads as a removable chip — the
                // detail is now set, so show it as a settled value, not a CTA.
                : InputChip(
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: Text('Due ${dateKey(_due!)}'),
                    onPressed: _pickDate,
                    onDeleted: () => setState(() => _due = null),
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              TextButton(
                onPressed: _saving
                    ? null
                    : () {
                        if (context.canPop()) context.pop();
                      },
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                child: const Text('Cancel'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        unawaited(HapticFeedback.selectionClick());
                        unawaited(_save());
                      },
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Save task'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
