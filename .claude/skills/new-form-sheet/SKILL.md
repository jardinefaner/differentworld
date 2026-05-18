---
name: new-form-sheet
description: Scaffold a bottom-sheet form with DismissGuard + DestructiveButton patterns. Use when adding a new create/edit form.
---

# /new-form-sheet — scaffold a form sheet

## Template

```dart
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FooFormSheet extends ConsumerStatefulWidget {
  const FooFormSheet({this.foo, super.key});

  final Foo? foo;

  static Future<void> show(BuildContext context, {Foo? foo}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FooFormSheet(foo: foo),
    );
  }

  @override
  ConsumerState<FooFormSheet> createState() => _FooFormSheetState();
}

class _FooFormSheetState extends ConsumerState<FooFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.foo != null;

  bool _isDirty() {
    final original = widget.foo;
    if (original == null) {
      return _name.text.trim().isNotEmpty;
    }
    return _name.text.trim() != original.name;
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.foo?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      // ... ref.read(actions).create / update
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'foos'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final foo = widget.foo;
    if (foo == null) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete?',
      message: 'This cannot be undone.',
      confirmLabel: 'Delete',
    );
    if (!confirmed || !mounted) return;
    // ... ref.read(actions).delete(foo.id)
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DismissGuard(
      isDirty: _isDirty,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
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
                      _isEdit ? 'Edit foo' : 'New foo',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      autofocus: !_isEdit,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required' : null,
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
                      children: [
                        if (_isEdit)
                          DestructiveButton(
                            label: 'Delete',
                            onPressed: _saving ? null : _delete,
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
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
        ),
      ),
    );
  }
}
```

## Checklist

- [ ] Wrapped in `DismissGuard` with `_isDirty()` that compares to the
      loaded entity (or "any input" for new)
- [ ] `MediaQuery.viewInsetsOf(context).bottom` for keyboard inset
- [ ] Drag handle at the top (visual affordance for swipe-down)
- [ ] Loading spinner inside the FilledButton during save, not a
      full-screen overlay
- [ ] `DestructiveButton` at the left of the action row in edit mode
- [ ] `if (!mounted) return;` after every `await`
- [ ] Optimistic write: the Drift mutation, not a Supabase call
