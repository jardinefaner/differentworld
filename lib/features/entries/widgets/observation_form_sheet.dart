import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/dismiss_guard.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Modal bottom sheet for creating or editing an observation.
///
/// On create: needs a groupId (the classroom context). Subject is
/// picked from the room's roster via a chip row at the top. Note text
/// is required. Photo capture is deferred to a follow-up.
///
/// On edit: subject + group are locked; only the note text is mutable.
class ObservationFormSheet extends ConsumerStatefulWidget {
  const ObservationFormSheet({
    this.groupId,
    this.initialSubjectId,
    this.existing,
    super.key,
  });

  /// Required when creating. Optional when editing (uses existing.groupId).
  final String? groupId;

  /// Pre-select a subject when creating (e.g. tapped from a roster).
  final String? initialSubjectId;

  /// Edit mode: pass the existing entry.
  final Entry? existing;

  static Future<void> show(
    BuildContext context, {
    String? groupId,
    String? initialSubjectId,
    Entry? existing,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ObservationFormSheet(
        groupId: groupId,
        initialSubjectId: initialSubjectId,
        existing: existing,
      ),
    );
  }

  @override
  ConsumerState<ObservationFormSheet> createState() =>
      _ObservationFormSheetState();
}

class _ObservationFormSheetState extends ConsumerState<ObservationFormSheet> {
  late final TextEditingController _textCtrl;
  String? _subjectId;
  bool _saving = false;
  bool _photoUploading = false;
  String? _error;

  /// Pre-generated entry id when creating. Photo uploads use this in
  /// the storage path so the path is stable even if the form is
  /// re-mounted (e.g. on rebuild from a draft). For edit mode it's
  /// just the existing entry id.
  late final String _entryId;

  /// Photo URL — already in Storage. Persisted to the entry's row at
  /// save time. Null = no photo (or none yet).
  String? _photoUrl;

  bool get _isEdit => widget.existing != null;

  String get _effectiveGroupId =>
      widget.existing?.groupId ?? widget.groupId ?? '';

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.existing?.body ?? '');
    _subjectId = widget.existing?.subjectId ?? widget.initialSubjectId;
    _entryId = widget.existing?.id ?? const Uuid().v4();
    _photoUrl = widget.existing?.photoUrl;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  bool _isDirty() {
    final original = widget.existing;
    if (original == null) {
      return _textCtrl.text.trim().isNotEmpty ||
          _subjectId != null ||
          _photoUrl != null;
    }
    return _textCtrl.text.trim() != (original.body ?? '') ||
        _subjectId != original.subjectId ||
        _photoUrl != original.photoUrl;
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photoUploading) return;
    final picker = ref.read(photoServiceProvider);
    XFile? picked;
    try {
      picked = await picker.pickPhoto(source);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'observations'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not open the picker.');
      return;
    }
    if (picked == null) return;
    setState(() {
      _photoUploading = true;
      _error = null;
    });
    try {
      final url = await picker.uploadOnly(
        entityKind: 'observation',
        entityId: _entryId,
        picked: picked,
      );
      if (!mounted) return;
      setState(() => _photoUrl = url);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'observations'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not upload that photo.');
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  void _clearPhoto() {
    setState(() => _photoUrl = null);
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _textCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Add a note before saving.');
      return;
    }
    if (_subjectId == null) {
      setState(() => _error = 'Pick a student first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final actions = ref.read(entryActionsProvider);
      if (_isEdit) {
        await actions.updateText(
          id: widget.existing!.id,
          text: text,
          photoUrl: _photoUrl,
        );
      } else {
        await actions.createObservation(
          subjectId: _subjectId!,
          groupId: _effectiveGroupId,
          text: text,
          photoUrl: _photoUrl,
          id: _entryId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'entries'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete this observation?',
      message: "This can't be undone.",
    );
    if (!confirmed || !mounted) return;
    setState(() => _saving = true);
    try {
      await ref.read(entryActionsProvider).delete(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'entries'),
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not delete. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final subjectsAsync = _effectiveGroupId.isEmpty
        ? const AsyncValue<List<Subject>>.data([])
        : ref.watch(subjectsInGroupProvider(_effectiveGroupId));

    return DismissGuard(
      isDirty: _isDirty,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
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
                    _isEdit ? 'Edit observation' : 'New observation',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),

                  // Subject picker — read-only chip on edit, scrollable
                  // row of avatars on create.
                  if (_isEdit)
                    _SelectedSubjectChip(subjectId: _subjectId)
                  else
                    subjectsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
                      ),
                      error: (_, _) => Text(
                        'Could not load students.',
                        style: theme.textTheme.bodySmall,
                      ),
                      data: (subjects) {
                        if (subjects.isEmpty) {
                          return Text(
                            'No students in this classroom yet.',
                            style: theme.textTheme.bodySmall,
                          );
                        }
                        return SizedBox(
                          height: 86,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: subjects.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, i) {
                              final s = subjects[i];
                              final selected = s.id == _subjectId;
                              return _SubjectPick(
                                subject: s,
                                selected: selected,
                                onTap: () =>
                                    setState(() => _subjectId = s.id),
                              );
                            },
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: _textCtrl,
                    autofocus: !_isEdit && _subjectId != null,
                    minLines: 4,
                    maxLines: 10,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'What happened?',
                      hintText: 'A short narrative — what the child did, '
                          'said, learned, struggled with.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PhotoRow(
                    photoUrl: _photoUrl,
                    uploading: _photoUploading,
                    onCamera: () => _pickPhoto(ImageSource.camera),
                    onGallery: () => _pickPhoto(ImageSource.gallery),
                    onClear: _clearPhoto,
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
                      if (_isEdit &&
                          ref.watch(viewerProvider).canManageProgram)
                        DestructiveButton(
                          label: 'Delete',
                          onPressed: _saving ? null : _delete,
                        ),
                      const Spacer(),
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
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isEdit ? 'Save' : 'Add observation'),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(48),
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.7)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(48),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PersonAvatar(
              name: '${subject.firstName} ${subject.lastName}',
              photoUrl: subject.photoUrl,
              radius: 22,
            ),
            const SizedBox(height: 4),
            Text(
              subject.firstName,
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedSubjectChip extends ConsumerWidget {
  const _SelectedSubjectChip({required this.subjectId});

  final String? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subjectId == null) return const SizedBox.shrink();
    // We don't have a single-subject provider yet — read once via DB.
    return FutureBuilder<Subject?>(
      future: () async {
        final db = await ref.read(appDatabaseProvider.future);
        return (db.select(db.subjects)
              ..where((s) => s.id.equals(subjectId!)))
            .getSingleOrNull();
      }(),
      builder: (context, snap) {
        final theme = Theme.of(context);
        final s = snap.data;
        if (s == null) {
          return const SizedBox.shrink();
        }
        final name = '${s.firstName} ${s.lastName}';
        return Row(
          children: [
            PersonAvatar(name: name, photoUrl: s.photoUrl),
            const SizedBox(width: 8),
            Text(name, style: theme.textTheme.titleMedium),
          ],
        );
      },
    );
  }
}

/// Photo affordance for the observation form. Two states:
/// - No photo yet: row of `Camera` / `Library` buttons.
/// - Photo set: thumbnail with an X to clear + a "Replace" button.
/// Upload state shows a small linear progress beneath.
class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.photoUrl,
    required this.uploading,
    required this.onCamera,
    required this.onGallery,
    required this.onClear,
  });

  final String? photoUrl;
  final bool uploading;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPhoto = photoUrl != null && !uploading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (uploading)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Uploading photo…',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          )
        else if (hasPhoto)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: photoUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                      width: 56,
                      height: 56,
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Photo attached',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Remove photo',
                  icon: Icon(Icons.close, color: theme.colorScheme.error),
                  onPressed: onClear,
                ),
              ],
            ),
          ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: uploading ? null : onCamera,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(hasPhoto ? 'Replace · Camera' : 'Camera'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: uploading ? null : onGallery,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(hasPhoto ? 'Replace · Library' : 'Library'),
            ),
          ],
        ),
      ],
    );
  }
}
