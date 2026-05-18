import 'package:cached_network_image/cached_network_image.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
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

  /// Local working copy of attachment URLs in display order. On open
  /// we seed this from the existing attachments stream (edit mode);
  /// the user adds/removes locally; on save we diff against the
  /// original list and create/delete the matching attachment rows.
  List<String> _photos = const [];

  /// Snapshot of the original attachment URLs at form-open time. Used
  /// for the diff on save and for the dirty check.
  List<String> _originalPhotos = const [];

  /// Map URL → existing attachment id, for the delete diff on save.
  /// New photos uploaded in this session won't appear here.
  Map<String, String> _attachmentIdByUrl = const {};

  /// True once we've seeded `_photos` from the stream (edit mode).
  /// New-observation mode flips this true immediately in initState.
  bool _seededAttachments = false;

  bool get _isEdit => widget.existing != null;

  String get _effectiveGroupId =>
      widget.existing?.groupId ?? widget.groupId ?? '';

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.existing?.body ?? '');
    _subjectId = widget.existing?.subjectId ?? widget.initialSubjectId;
    _entryId = widget.existing?.id ?? const Uuid().v4();
    if (!_isEdit) _seededAttachments = true;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  /// Seeded once per form-open from the `attachmentsForEntityProvider`
  /// stream. After this, the stream can refresh independently but
  /// the form holds local state until save.
  void _seedAttachments(List<Attachment> rows) {
    if (_seededAttachments) return;
    _photos = rows.map((a) => a.url).toList(growable: false);
    _originalPhotos = _photos;
    _attachmentIdByUrl = {for (final a in rows) a.url: a.id};
    _seededAttachments = true;
  }

  bool _isDirty() {
    final original = widget.existing;
    if (original == null) {
      return _textCtrl.text.trim().isNotEmpty ||
          _subjectId != null ||
          _photos.isNotEmpty;
    }
    final samePhotos =
        _photos.length == _originalPhotos.length &&
        List.generate(
          _photos.length,
          (i) => _photos[i] == _originalPhotos[i],
        ).every((b) => b);
    return _textCtrl.text.trim() != (original.body ?? '') ||
        _subjectId != original.subjectId ||
        !samePhotos;
  }

  Future<void> _addPhoto(ImageSource source) async {
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
      setState(() => _photos = [..._photos, url]);
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

  void _removePhotoAt(int index) {
    if (index < 0 || index >= _photos.length) return;
    setState(() {
      final next = [..._photos]..removeAt(index);
      _photos = next;
    });
  }

  Future<void> _showAddPhotoSheet() async {
    if (_photoUploading) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Library'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    await _addPhoto(source);
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
      final attachments = ref.read(attachmentActionsProvider);
      if (_isEdit) {
        await actions.updateText(
          id: widget.existing!.id,
          text: text,
        );
        // Diff attachments: delete those gone, add new ones in order.
        final originalSet = _originalPhotos.toSet();
        final currentSet = _photos.toSet();
        for (final url in originalSet.difference(currentSet)) {
          final id = _attachmentIdByUrl[url];
          if (id != null) await attachments.remove(id);
        }
        // For order changes / new uploads, walk in order and reorder
        // existing rows / create rows for new URLs.
        for (var i = 0; i < _photos.length; i++) {
          final url = _photos[i];
          final existingId = _attachmentIdByUrl[url];
          if (existingId != null) {
            await attachments.reorder(id: existingId, sortOrder: i);
          } else {
            await attachments.add(
              entityKind: 'entry',
              entityId: _entryId,
              url: url,
              sortOrder: i,
            );
          }
        }
      } else {
        // createObservation handles its own attachment writes from
        // photoUrls; it preserves order.
        await actions.createObservation(
          subjectId: _subjectId!,
          groupId: _effectiveGroupId,
          text: text,
          photoUrls: _photos,
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

    // Seed the photos working-copy on first arrival of the attachments
    // stream (edit mode). For new-observation mode `_seededAttachments`
    // was set in initState so we never enter this branch.
    if (_isEdit && !_seededAttachments) {
      ref
          .watch(attachmentsForEntityProvider((kind: 'entry', id: _entryId)))
          .whenData(_seedAttachments);
    }

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
                  _PhotosGrid(
                    photos: _photos,
                    uploading: _photoUploading,
                    onAdd: _showAddPhotoSheet,
                    onView: (i) => PhotoViewer.open(
                      context,
                      urls: _photos,
                      initialIndex: i,
                    ),
                    onRemove: _removePhotoAt,
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

/// Multi-photo grid for the observation form. Horizontal scroll of
/// 72dp thumbs followed by a "+" tile. Each thumb has an X in the
/// corner; tap the thumb itself to open the fullscreen [PhotoViewer]
/// for pinch-zoom. Upload state shows as a 72dp shimmer tile inline.
class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({
    required this.photos,
    required this.uploading,
    required this.onAdd,
    required this.onView,
    required this.onRemove,
  });

  final List<String> photos;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onView;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Photos',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < photos.length; i++) ...[
                _PhotoTile(
                  url: photos[i],
                  onTap: () => onView(i),
                  onRemove: () => onRemove(i),
                ),
                const SizedBox(width: 8),
              ],
              if (uploading) ...[
                _UploadingTile(),
                const SizedBox(width: 8),
              ],
              _AddTile(onTap: uploading ? null : onAdd),
            ],
          ),
        ),
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.url,
    required this.onTap,
    required this.onRemove,
  });

  final String url;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  errorWidget: (_, _, _) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined, size: 20),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: Material(
              color: theme.colorScheme.errorContainer,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.close,
                    size: 14,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              'Add',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
