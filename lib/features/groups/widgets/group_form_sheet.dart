import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Modal bottom sheet for creating or editing a Group ("Classroom" in v1
/// UI). Pass an existing `group` to edit, or null to create.
class GroupFormSheet extends ConsumerStatefulWidget {
  const GroupFormSheet({this.group, super.key});

  final Group? group;

  static Future<void> show(BuildContext context, {Group? group}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GroupFormSheet(group: group),
    );
  }

  @override
  ConsumerState<GroupFormSheet> createState() => _GroupFormSheetState();
}

class _GroupFormSheetState extends ConsumerState<GroupFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageRangeController;

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.group != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _ageRangeController = TextEditingController(
      text: widget.group?.ageRange ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageRangeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController.text.trim();
    final ageRange = _ageRangeController.text.trim();

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final actions = ref.read(groupActionsProvider);
      if (_isEdit) {
        await actions.update(
          id: widget.group!.id,
          name: name,
          ageRange: ageRange.isEmpty ? null : ageRange,
        );
      } else {
        await actions.create(
          name: name,
          ageRange: ageRange.isEmpty ? null : ageRange,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'groups'),
      );
      if (!mounted) return;
      setState(
        () => _error = 'Could not save the classroom. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  _isEdit ? 'Edit classroom' : 'New classroom',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Classroom name',
                    hintText: 'e.g. Sunshine Room',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Required';
                    if (v.length < 2) return 'Too short';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ageRangeController,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: const InputDecoration(
                    labelText: 'Age range (optional)',
                    hintText: 'e.g. 3–4 years',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(_isEdit ? 'Save' : 'Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
