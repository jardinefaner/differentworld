import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/incidents/incidents_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Log a structured incident (docs/WORKFLOWS.md gap #3): the child, the
/// kind, what happened, what staff did, and whether the family was told.
/// A first-class compliance record — `entries.kind='incident'` — distinct
/// from a free-text observation. v1 is text + structure; photos are a
/// deliberate fast-follow (the narrative is the compliance core).
class IncidentFormScreen extends ConsumerStatefulWidget {
  const IncidentFormScreen({this.initialSubjectId, super.key});

  /// Pre-select the child (e.g. launched from their detail screen).
  final String? initialSubjectId;

  @override
  ConsumerState<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends ConsumerState<IncidentFormScreen> {
  late final TextEditingController _narrative;
  late final TextEditingController _action;
  String? _subjectId;
  IncidentType _type = IncidentType.injury;
  bool _parentNotified = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _narrative = TextEditingController();
    _action = TextEditingController();
    _subjectId = widget.initialSubjectId;
  }

  @override
  void dispose() {
    _narrative.dispose();
    _action.dispose();
    super.dispose();
  }

  bool _isDirty() =>
      _narrative.text.trim().isNotEmpty ||
      _action.text.trim().isNotEmpty ||
      _subjectId != null ||
      _parentNotified;

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this incident?'),
        content: const Text(
          "You haven't saved it. Leaving will drop what you typed.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save(List<Subject> subjects) async {
    if (_saving) return;
    final narrative = _narrative.text.trim();
    if (_subjectId == null) {
      setState(() => _error = 'Pick a child first.');
      return;
    }
    if (narrative.isEmpty) {
      setState(() => _error = 'Describe what happened before saving.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      Subject? subject;
      for (final s in subjects) {
        if (s.id == _subjectId) {
          subject = s;
          break;
        }
      }
      await ref.read(entryActionsProvider).createIncident(
            subjectId: _subjectId!,
            groupId: subject?.groupId,
            text: narrative,
            incidentType: _type.id,
            actionTaken: _action.text.trim(),
            parentNotified: _parentNotified,
          );
      if (!mounted) return;
      if (context.canPop()) context.pop();
    } on Object catch (e, st) {
      // on Object, not Exception — the repo can throw a StateError
      // ("No Space") which must surface as the inline retry, not a
      // red screen.
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'incidents'),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjectsAsync = ref.watch(subjectsInSpaceProvider);
    final subjects = subjectsAsync.value ?? const <Subject>[];

    return PopScope(
      canPop: !_isDirty(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Save already committing — don't pop a "discard?" dialog over a
        // write that's already landing.
        if (_saving) return;
        if (!_isDirty()) {
          if (context.mounted && context.canPop()) context.pop();
          return;
        }
        final ok = await _confirmDiscard();
        if (ok && context.mounted && context.canPop()) context.pop();
      },
      child: EdgeScaffold(
        body: FormBody(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const ContentHeader(
              title: 'Log an incident',
              subtitle: 'A bump, a conflict, an illness — the structured '
                  'record families and licensing can rely on.',
            ),

            // Child picker.
            Text('Child', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            if (subjectsAsync.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (subjects.isEmpty)
              Text(
                'No children on file yet.',
                style: theme.textTheme.bodySmall,
              )
            else
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: subjects.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) {
                    final s = subjects[i];
                    return _SubjectPick(
                      subject: s,
                      selected: s.id == _subjectId,
                      onTap: () => setState(() => _subjectId = s.id),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),

            // Incident type.
            Text('Type', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in IncidentType.values)
                  ChoiceChip(
                    avatar: Icon(
                      t.icon,
                      size: 18,
                      color: t == _type
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(t.label),
                    selected: t == _type,
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // What happened.
            TextField(
              controller: _narrative,
              autofocus: _subjectId != null,
              minLines: 3,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'Where, when, who was involved, how it resolved.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // What staff did.
            TextField(
              controller: _action,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Action taken (optional)',
                hintText: 'Ice applied, redirected, parent called…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Family notified'),
              subtitle: const Text('Mark once you’ve told a parent/guardian'),
              value: _parentNotified,
              onChanged: (v) => setState(() => _parentNotified = v),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _save(subjects),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Saving…' : 'Log incident'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectPick extends StatelessWidget {
  const _SubjectPick({
    required this.subject,
    required this.selected,
    required this.onTap,
  });

  final Subject subject;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = '${subject.firstName} ${subject.lastName}'.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: PersonAvatar(
                name: name,
                photoUrl: subject.photoUrl,
                radius: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subject.firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: selected ? FontWeight.w600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
