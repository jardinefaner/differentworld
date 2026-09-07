import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/game_content/content_kinds.dart';
import 'package:differentworld/features/game_content/our_content.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/library/ours/:kind/new` and `/library/ours/:kind/edit?id=` — write one
/// item of any authorable kind. A PAGE, not a sheet: this is a task, and tasks
/// are pages in this app (CLAUDE.md, "Modals — a glance, never a task").
///
/// The whole form is generated from the kind's [ContentKindSpec], so adding a
/// content kind never means writing a form.
///
/// An edit takes the item's ID rather than the item, and resolves it from the
/// same provider the list watches — so the edit route is a real deep link, not
/// a screen you can only reach by tapping a row.
class OurContentFormScreen extends ConsumerWidget {
  const OurContentFormScreen({required this.kind, this.id, super.key});

  final String kind;

  /// The id of the item being edited, or null to write a new one.
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(viewerProvider) is GuardianViewer) {
      return const EdgeScaffold(
        body: NoAccess(
          title: 'This is for the team',
          message: "Activity content is written by the program's staff.",
        ),
      );
    }
    if (id == null) return OurContentForm(kind: kind);
    // Resolving through the provider (not a passed object) is what makes the
    // edit link survive a cold launch.
    return ref
        .watch(ourContentProvider(kind))
        .when(
          loading: () => const EdgeScaffold(body: LoadingSlot()),
          error: (e, _) => EdgeScaffold(
            body: ErrorState(
              title: "Couldn't open that",
              detail: '$e',
              onRetry: () => ref.invalidate(ourContentProvider(kind)),
            ),
          ),
          data: (items) {
            for (final item in items) {
              if (item.id == id) {
                return OurContentForm(kind: kind, editing: item);
              }
            }
            return const EdgeScaffold(
              body: ErrorState(
                title: 'That one is gone',
                detail: 'It was removed, here or on another device.',
              ),
            );
          },
        );
  }
}

/// The form itself, once the item (if any) is in hand.
class OurContentForm extends ConsumerStatefulWidget {
  const OurContentForm({required this.kind, this.editing, super.key});

  final String kind;

  /// The item being edited, or null to write a new one.
  final OurContentItem? editing;

  @override
  ConsumerState<OurContentForm> createState() => _OurContentFormScreenState();
}

class _OurContentFormScreenState extends ConsumerState<OurContentForm> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = <String, TextEditingController>{};
  final _flags = <String, bool>{};
  bool _saving = false;
  bool _touched = false;

  ContentKindSpec? get _spec => specForKind(widget.kind);

  @override
  void initState() {
    super.initState();
    final spec = _spec;
    if (spec == null) return;
    final payload = widget.editing?.payload ?? const <String, Object?>{};
    for (final f in spec.fields) {
      if (f.shape == ContentFieldShape.flag) {
        _flags[f.key] = payload[f.key] == true;
      } else {
        _controllers[f.key] = TextEditingController(
          text: _initialText(payload[f.key]),
        )..addListener(_markTouched);
      }
    }
  }

  static String _initialText(Object? v) {
    if (v is String) return v;
    if (v is List) return v.map((e) => '$e').join('\n');
    return '';
  }

  void _markTouched() {
    if (!_touched) _touched = true;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c
        ..removeListener(_markTouched)
        ..dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _payload(ContentKindSpec spec) {
    final out = <String, Object?>{};
    for (final f in spec.fields) {
      switch (f.shape) {
        case ContentFieldShape.flag:
          out[f.key] = _flags[f.key] ?? false;
        case ContentFieldShape.list:
          final lines = (_controllers[f.key]?.text ?? '')
              .split('\n')
              .map((l) => l.trim())
              .where((l) => l.isNotEmpty)
              .toList();
          out[f.key] = lines;
        case ContentFieldShape.line:
        case ContentFieldShape.paragraph:
          final text = (_controllers[f.key]?.text ?? '').trim();
          if (text.isNotEmpty || f.required) out[f.key] = text;
      }
    }
    return out;
  }

  Future<void> _save(ContentKindSpec spec) async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final payload = _payload(spec);
      final actions = ref.read(ourContentActionsProvider);
      final editing = widget.editing;
      if (editing == null) {
        await actions.create(kind: spec.kind, payload: payload);
      } else {
        await actions.update(editing.id, payload);
      }
      _touched = false;
      if (navigator.canPop()) navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            editing == null ? 'Added to your ${spec.many}' : 'Saved',
          ),
        ),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't save: $e")));
    } finally {
      // In `finally`, not just the catch: a save that succeeds without popping
      // (the form as a root route) would otherwise leave the button disabled
      // forever with nothing on screen to say why.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec;
    if (spec == null) {
      return EdgeScaffold(
        body: ErrorState(
          title: "That isn't something you can write",
          detail: 'No form is defined for "${widget.kind}".',
        ),
      );
    }
    final editing = widget.editing != null;
    return DismissGuard(
      isDirty: () => _touched && !_saving,
      child: EdgeScaffold(
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                ContentHeader(
                  title: editing
                      ? 'Edit this ${spec.one}'
                      : 'Add a ${spec.one}',
                  subtitle: editing ? null : spec.blurb,
                ),
                for (final f in spec.fields) ...[
                  _Field(
                    field: f,
                    controller: _controllers[f.key],
                    flag: _flags[f.key] ?? false,
                    onFlag: (v) => setState(() {
                      _flags[f.key] = v;
                      _touched = true;
                    }),
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : () => _save(spec),
                  child: _saving
                      ? Semantics(
                          label: 'Saving',
                          child: const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Text(editing ? 'Save' : 'Keep it'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.field,
    required this.controller,
    required this.flag,
    required this.onFlag,
  });

  final ContentField field;
  final TextEditingController? controller;
  final bool flag;
  final ValueChanged<bool> onFlag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (field.shape == ContentFieldShape.flag) {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        subtitle: Text(
          flag ? field.trueLabel ?? 'True' : field.falseLabel ?? 'False',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        value: flag,
        onChanged: onFlag,
      );
    }
    final multiline =
        field.shape == ContentFieldShape.paragraph ||
        field.shape == ContentFieldShape.list;
    return TextFormField(
      controller: controller,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      minLines: multiline ? 2 : 1,
      maxLines: multiline ? 5 : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (!field.required) return null;
        return (v ?? '').trim().isEmpty
            ? 'Add ${field.label.toLowerCase()}'
            : null;
      },
    );
  }
}
