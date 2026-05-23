import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/multi_shot_camera.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/voice/deepgram_voice_service.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Create / edit observation as a real route.
///
/// Promoted from `observation_form_sheet.dart` (bottom-sheet) to
/// `/observations/new` and `/observations/:id/edit` in Wave 21. This
/// is the heaviest of the heavy forms — text, multi-photo upload,
/// subject picker, attachment diffing, delete affordance. As a
/// route it gets full chrome [☰] [←] (back doubles as cancel), the
/// layout law, and the keyboard inset for free.
///
/// **Modes**:
/// - Create: needs `groupId`; optional `initialSubjectId`.
/// - Edit: pass the `Entry` via go_router's `extra` (no extra DB
///   fetch — the entry is already loaded wherever the user came
///   from). `groupId` and `subjectId` are locked in edit mode.
///
/// **Dirty-state guard**: hitting back when there are unsaved
/// changes pops a confirm dialog so swipe-back / system-back
/// doesn't silently throw away typed text or unselected photos.
class ObservationFormScreen extends ConsumerStatefulWidget {
  const ObservationFormScreen({
    this.groupId,
    this.initialSubjectId,
    this.existing,
    super.key,
  });

  /// Required when creating. Optional when editing (uses
  /// `existing.groupId`).
  final String? groupId;

  /// Pre-select a subject when creating (e.g. tapped from a roster).
  final String? initialSubjectId;

  /// Edit mode: pass the existing entry.
  final Entry? existing;

  @override
  ConsumerState<ObservationFormScreen> createState() =>
      _ObservationFormScreenState();
}

class _ObservationFormScreenState
    extends ConsumerState<ObservationFormScreen> {
  late final TextEditingController _textCtrl;
  String? _subjectId;
  bool _saving = false;
  bool _photoUploading = false;
  String? _error;

  /// Pre-generated entry id when creating. Photo uploads use this in
  /// the storage path so the path is stable even if the form is re-
  /// mounted (e.g. on rebuild from a draft). For edit mode it's the
  /// existing entry id.
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

  // -- Voice dictation (Jordan persona; persona-audit 2026-05-22) --
  //
  // The form owns its OWN DeepgramVoiceController instance (NOT the
  // shared `deepgramVoiceProvider` singleton AppShell uses) so the
  // form's transcript stream is isolated from any concurrent voice
  // session on the omnibox bar. Otherwise both screens listen to the
  // same broadcast stream — `voice.start()` no-ops on the second
  // caller because `isActive` is already true, but BOTH listeners
  // receive every update and write the transcript into both fields
  // simultaneously. Preflight flagged this as a Stop-ship-WARNING
  // (lib/shared/widgets/app_shell.dart:309 + this file). Local
  // instance = clean encapsulation per the form's lifecycle.
  //
  // Constructed in initState, disposed in dispose. dispose() (not
  // cancel()) is the right teardown — it closes the broadcast stream
  // and disposes the underlying AudioRecorder; this instance won't
  // be reused after the form closes.
  late final DeepgramVoiceController _voice;
  StreamSubscription<VoiceUpdate>? _voiceSub;
  bool _voiceActive = false;
  String _voicePrefix = '';

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
    // Form-local voice controller (see field comment for rationale).
    _voice = DeepgramVoiceController();
  }

  @override
  void dispose() {
    // Order matters: tear down the voice subscription first (so no
    // late transcript can land in `_textCtrl` after dispose), then
    // fully dispose the local voice controller (closes the broadcast
    // stream + the underlying AudioRecorder — this instance won't be
    // reused), then the text controller. All unawaited; the WS /
    // recorder shut themselves down promptly anyway.
    unawaited(_voiceSub?.cancel());
    _voiceSub = null;
    unawaited(_voice.dispose());
    _textCtrl.dispose();
    super.dispose();
  }

  /// Toggle Deepgram dictation for the body field. Uses the FORM-
  /// LOCAL `_voice` controller (NOT the AppShell singleton) so the
  /// transcript stream is isolated. Same prefix-preservation pattern
  /// as the omnibox bar: snapshot whatever the user typed before the
  /// session starts, append the live transcript as it streams in.
  void _toggleVoice() {
    if (_voiceActive) {
      unawaited(_voice.stop());
      return;
    }
    _voicePrefix = _textCtrl.text;
    setState(() => _voiceActive = true);
    _voiceSub = _voice.updates.listen(_onVoiceUpdate);
    unawaited(_voice.start());
  }

  void _onVoiceUpdate(VoiceUpdate update) {
    if (!mounted) return;
    if (update.state == VoiceState.error) {
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      final msg = update.errorMessage ?? 'Voice dictation failed.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(msg)),
      );
      setState(() {});
      return;
    }
    final transcript = update.transcript.trim();
    final glue = (_voicePrefix.isEmpty || transcript.isEmpty) ? '' : ' ';
    final combined = '$_voicePrefix$glue$transcript';
    _textCtrl
      ..text = combined
      ..selection = TextSelection.collapsed(offset: combined.length);
    if (update.state == VoiceState.idle) {
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      setState(() {});
    }
  }

  /// Seeded once per form-open from the `attachmentsForEntityProvider`
  /// stream. After this, the stream can refresh independently but the
  /// form holds local state until save.
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
    final samePhotos = _photos.length == _originalPhotos.length &&
        List.generate(
          _photos.length,
          (i) => _photos[i] == _originalPhotos[i],
        ).every((b) => b);
    return _textCtrl.text.trim() != (original.body ?? '') ||
        _subjectId != original.subjectId ||
        !samePhotos;
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          "You haven't saved this observation. Leaving will drop "
          'what you typed.',
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

  /// Library / single-image picker path. Camera goes through
  /// [_takeBurstFromCamera] so the user can stay in the camera
  /// across multiple shots.
  Future<void> _addPhotoFromLibrary() async {
    if (_photoUploading) return;
    final picker = ref.read(photoServiceProvider);
    XFile? picked;
    try {
      picked = await picker.pickPhoto(ImageSource.gallery);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'observations',
        ),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not open the picker.');
      return;
    }
    if (picked == null) return;
    await _uploadAll(picker, [picked]);
  }

  /// Custom multi-shot camera. Returns when the user taps Done; the
  /// list may contain N photos. Each is uploaded in sequence.
  Future<void> _takeBurstFromCamera() async {
    if (_photoUploading) return;
    final captured = await MultiShotCamera.open(context);
    if (captured == null || captured.isEmpty || !mounted) return;
    await _uploadAll(ref.read(photoServiceProvider), captured);
  }

  /// Compress+upload each XFile in parallel, appending URLs to
  /// `_photos` as they finish.
  Future<void> _uploadAll(PhotoService service, List<XFile> picks) async {
    setState(() {
      _photoUploading = true;
      _error = null;
    });
    try {
      final urls = await Future.wait(
        picks.map(
          (pick) => service.uploadOnly(
            entityKind: 'observation',
            entityId: _entryId,
            picked: pick,
          ),
        ),
      );
      if (!mounted) return;
      setState(() => _photos = [..._photos, ...urls]);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'observations',
        ),
      );
      if (!mounted) return;
      setState(() => _error = picks.length == 1
          ? 'Could not upload that photo.'
          : "Some photos didn't upload. Try again.");
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
              subtitle: const Text('Stay in camera and snap several'),
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
    if (source == null || !mounted) return;
    if (source == ImageSource.camera) {
      await _takeBurstFromCamera();
    } else {
      await _addPhotoFromLibrary();
    }
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
      if (context.canPop()) context.pop();
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
      if (context.canPop()) context.pop();
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
    final subjectsAsync = _effectiveGroupId.isEmpty
        ? const AsyncValue<List<Subject>>.data([])
        : ref.watch(subjectsInGroupProvider(_effectiveGroupId));

    // Seed the photos working-copy on first arrival of the
    // attachments stream (edit mode). For new-observation mode
    // `_seededAttachments` was set in initState so we never enter
    // this branch.
    if (_isEdit && !_seededAttachments) {
      ref
          .watch(attachmentsForEntityProvider((kind: 'entry', id: _entryId)))
          .whenData(_seedAttachments);
    }

    return PopScope(
      canPop: !_isDirty(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (!_isDirty()) {
          if (context.mounted && context.canPop()) context.pop();
          return;
        }
        final ok = await _confirmDiscard();
        if (ok && context.mounted && context.canPop()) context.pop();
      },
      child: EdgeScaffold(
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            ContentHeader(
              title: _isEdit ? 'Edit observation' : 'New observation',
              subtitle: _isEdit
                  ? null
                  : 'A short narrative — what the child did, said, '
                      'learned, struggled with.',
            ),

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
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final s = subjects[i];
                        final selected = s.id == _subjectId;
                        return _SubjectPick(
                          subject: s,
                          selected: selected,
                          onTap: () => setState(() => _subjectId = s.id),
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
              decoration: InputDecoration(
                labelText: 'What happened?',
                helperText: _voiceActive ? 'Listening…' : null,
                border: const OutlineInputBorder(),
                // Mic lives as the suffix so it sits adjacent to the
                // text the user is dictating into. Tap toggles a live
                // Deepgram session; the transcript appends to the
                // existing prefix so typed-then-dictated works.
                suffixIcon: IconButton(
                  tooltip: _voiceActive
                      ? 'Stop dictation'
                      : 'Dictate by voice',
                  icon: Icon(
                    _voiceActive
                        ? Icons.stop_circle
                        : Icons.mic_none_outlined,
                    color: _voiceActive
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  onPressed: _toggleVoice,
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                if (_isEdit && ref.watch(viewerProvider).canManageSpace)
                  DestructiveButton(
                    label: 'Delete',
                    onPressed: _saving ? null : _delete,
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _saving
                        ? 'Saving…'
                        : (_isEdit ? 'Save' : 'Add observation'),
                  ),
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
    // No single-subject provider; one-shot read via DB.
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
        if (s == null) return const SizedBox.shrink();
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
/// 72-dp thumbs followed by a "+" tile. Each thumb has an X in the
/// corner; tap the thumb itself to open the fullscreen [PhotoViewer]
/// for pinch-zoom. Upload state shows as a 72-dp shimmer tile
/// inline.
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
                child: PersonPhotoNetwork(
                  urlOrPath: url,
                  placeholderBuilder: (_) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                  ),
                  errorBuilder: (_) => Container(
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
