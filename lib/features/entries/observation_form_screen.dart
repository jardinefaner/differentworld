import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/widgets/observation_form_parts.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/multi_shot_camera.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/features/voice/deepgram_voice_service.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:super_clipboard/super_clipboard.dart';
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

class _ObservationFormScreenState extends ConsumerState<ObservationFormScreen> {
  late final TextEditingController _textCtrl;
  String? _subjectId;
  bool _saving = false;
  bool _photoUploading = false;
  /// Wave 117: true while the user is hovering with a dragged file
  /// (from the OS or the browser) over the photo grid. Drives the
  /// hover-highlight on the DropTarget.
  bool _isDragging = false;
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

  /// Map URL → the attachment id we PRE-GENERATED for a photo uploaded this
  /// session. The same id was passed to `uploadOnly(entityId:)`, so the
  /// attachment row MUST be created with it — otherwise the upload queue's
  /// `updateUrl(id)` can't patch a deferred (offline) upload and the photo is
  /// silently lost. Keyed by url (uploadOnly returns a unique path/token).
  Map<String, String> _newAttIds = const {};

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
    // Wave 99: an in-flight photo upload counts as dirty. Without
    // this, the user can swipe-dismiss the route while bytes are
    // still uploading — `_photos` is still `[]` (the URL hasn't
    // been appended yet), so `canPop` lets the route die, the
    // upload completes after dispose, the form state is gone, and
    // the bytes are orphaned in Storage with nothing referencing
    // them. Treating mid-upload as dirty forces the discard
    // confirmation, which gives the upload time to finish.
    if (_photoUploading) return true;
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

  /// Wave 124: clipboard paste handler. When the kid / teacher hits
  /// Cmd+V (or Ctrl+V on Windows/Linux) inside the body field, we
  /// read the system clipboard via super_clipboard. If it carries an
  /// image (e.g. a screenshot the teacher copied), we extract the
  /// bytes, write a temp XFile, and route through _uploadAll. If
  /// there's no image (just text), we let the default text-paste
  /// happen by NOT consuming the shortcut.
  Future<void> _handlePasteShortcut() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return;
    final reader = await clipboard.read();
    // png + jpeg cover ~all screenshot / "copy image" sources.
    for (final fmt in const [Formats.png, Formats.jpeg]) {
      if (!reader.canProvide(fmt)) continue;
      final completer = Completer<Uint8List?>();
      reader.getFile(fmt, (file) async {
        try {
          final bytes = await file.readAll();
          completer.complete(bytes);
        } on Object {
          completer.complete(null);
        }
      }, onError: (_) => completer.complete(null));
      final bytes = await completer.future;
      if (bytes == null || bytes.isEmpty) continue;
      // Hand the bytes to the same path the DropTarget uses. XFile.fromData
      // holds them in memory (no temp file) so this works on web too — the
      // old getTemporaryDirectory()/File() write crashed on web (no
      // filesystem). _handleDroppedFiles filters on name + mimeType, not
      // path, so the in-memory XFile passes its image check.
      final name = 'paste_${DateTime.now().millisecondsSinceEpoch}'
          '.${fmt == Formats.png ? 'png' : 'jpg'}';
      final mime = fmt == Formats.png ? 'image/png' : 'image/jpeg';
      await _handleDroppedFiles([
        XFile.fromData(bytes, name: name, mimeType: mime),
      ]);
      return;
    }
    // No image on the clipboard — fall through so the default text
    // paste handling runs (we don't intercept the keystroke).
  }

  /// Wave 117: handler for files dropped onto the photo grid from the
  /// OS (desktop) or the browser (web). Each `DropItemFile` carries a
  /// path; we filter to image MIME types, convert to `XFile`, and
  /// reuse the same `_uploadAll` path the file-picker uses.
  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (_photoUploading || files.isEmpty) return;
    // Filter to image MIME types — desktop_drop accepts everything
    // the OS drag source offers (PDFs, .txts, screenshots). Tag what
    // we can; for paths whose extension is something we know is an
    // image, accept; reject everything else.
    final images = <XFile>[];
    const imageExts = {
      '.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic', '.heif',
    };
    for (final f in files) {
      final name = f.name.toLowerCase();
      final mime = f.mimeType?.toLowerCase() ?? '';
      final isImage = mime.startsWith('image/') ||
          imageExts.any(name.endsWith);
      if (isImage) images.add(f);
    }
    if (images.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Only images can be attached to observations.'),
        ),
      );
      return;
    }
    await _uploadAll(ref.read(photoServiceProvider), images);
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
      // Pre-generate each attachment's id and pass it to uploadOnly AS the
      // entityId, so a deferred (offline) upload's queue-side `updateUrl(id)`
      // patches the SAME attachment row we create on save. (Wave 99 aligned
      // the kind to 'attachment' so the queue had a resolver; this fixes the
      // id — passing `_entryId` here meant the queue patched a non-existent
      // row and offline-captured photos were silently lost forever.)
      final newPairs = await Future.wait(
        picks.map((pick) async {
          final attId = const Uuid().v4();
          final url = await service.uploadOnly(
            entityKind: 'attachment',
            entityId: attId,
            picked: pick,
          );
          return (url: url, id: attId);
        }),
      );
      if (!mounted) return;
      setState(() {
        _photos = [..._photos, ...newPairs.map((p) => p.url)];
        _newAttIds = {
          ..._newAttIds,
          for (final p in newPairs) p.url: p.id,
        };
      });
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'observations',
        ),
      );
      if (!mounted) return;
      setState(
        () => _error = picks.length == 1
            ? 'Could not upload that photo.'
            : "Some photos didn't upload. Try again.",
      );
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
    // Wave 107: on web, MultiShotCamera imports dart:io and crashes
    // — skip the picker, go straight to the file-upload path. The
    // image_picker library handler uses an <input type=file> on web,
    // which is the correct desktop UX.
    if (kIsWeb) {
      await _addPhotoFromLibrary();
      return;
    }
    final source = await showGlassSheet<ImageSource>(
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
              // Pin the id we uploaded under, so a deferred offline upload
              // patches THIS row (else silent loss). Always set for a
              // session-uploaded photo; null → a fresh id (defensive).
              id: _newAttIds[url],
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
        //
        // Snapshot the live block at save-commit time (per the rules in
        // docs/LIVE_BLOCK_CONTEXT.md — the block belongs to the moment,
        // not the clock-tick). ref.read, not watch, so the save handler
        // captures the block at this instant; no subscription overhead.
        final liveBlock = ref.read(liveBlockProvider);
        await actions.createObservation(
          subjectId: _subjectId!,
          groupId: _effectiveGroupId,
          text: text,
          photoUrls: _photos,
          // Aligned with photoUrls — the pre-generated ids so deferred
          // offline uploads patch the right attachment rows.
          photoIds: [
            for (final url in _photos) _newAttIds[url] ?? const Uuid().v4(),
          ],
          scheduleBlockId: liveBlock?.blockId,
          id: _entryId,
        );
      }
      if (!mounted) return;
      if (context.canPop()) context.pop();
    } on Object catch (e, st) {
      // on Object, not on Exception: the repo can throw a StateError
      // ("No Space") — an Error subtype — which would otherwise escape
      // the catch and red-screen instead of surfacing the inline retry.
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'entries'),
      );
      if (!mounted) return;
      setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Author OR director can delete. Mirrors Wave 104 policy — a
  /// teacher who fat-fingers a save shouldn't have to escalate.
  bool _canDelete(WidgetRef ref) {
    final viewer = ref.watch(viewerProvider);
    if (viewer.canManageSpace) return true;
    final myMemberId = viewer.member?.id;
    final authorId = widget.existing?.recordedBy;
    return myMemberId != null && authorId != null && myMemberId == authorId;
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
    } on Object catch (e, st) {
      // on Object, not on Exception — see _save: a repo StateError must
      // surface as the inline retry, not a red screen.
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
    // "Bento everywhere" for forms = a toggle-gated responsive 2-column
    // field layout. This form has NO two adjacent SHORT fields to pair:
    // it's a subject picker (full-width horizontal scroller) + one long
    // multi-line narrative + a full-width photo grid. Pairing the long
    // narrative or the photo grid into a half-column is exactly what the
    // spec forbids ("long fields stay full-width"), so there are no fake
    // columns here — when bento is on we just give the single column more
    // room (900 vs 600) so the narrative + photos breathe on desktop.
    // Phone stays full-width regardless (the cap is the binding limit
    // only above ~600dp).
    final bento = bentoEnabled(ref, perScreen: null);
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
        body: FormBody(
          maxWidth: bento ? 900 : 600,
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
              ObservationSelectedSubjectChip(subjectId: _subjectId)
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
                        return ObservationSubjectPick(
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
            // Wave 124: Cmd/Ctrl+V paste-image intercept. When the
            // clipboard carries an image (e.g. a teacher pasted a
            // screenshot), we route it through _handleDroppedFiles
            // and skip the default text paste. Text-only clipboard
            // contents fall through to TextField's normal paste.
            CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
                    () => unawaited(_handlePasteShortcut()),
                const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                    () => unawaited(_handlePasteShortcut()),
              },
              child: TextField(
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
                  tooltip: _voiceActive ? 'Stop dictation' : 'Dictate by voice',
                  icon: Icon(
                    _voiceActive ? Icons.stop_circle : Icons.mic_none_outlined,
                    color: _voiceActive
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  onPressed: _toggleVoice,
                ),
              ),
            ),
            ),
            const SizedBox(height: 16),
            // Wave 117: DropTarget accepts files dragged from the OS
            // (or the browser) directly onto the photos grid. _isDragging
            // toggles a hover state so the user sees a clear drop zone
            // appear when their finger / cursor crosses the boundary.
            // The drop handler reuses the existing _uploadAll pipeline,
            // so compression + offline queueing + the 'pending:' token
            // all work identically to file-picker uploads.
            DropTarget(
              onDragEntered: (_) => setState(() => _isDragging = true),
              onDragExited: (_) => setState(() => _isDragging = false),
              onDragDone: (detail) {
                setState(() => _isDragging = false);
                unawaited(_handleDroppedFiles(detail.files));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: _isDragging
                      ? Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                        )
                      : Border.all(
                          color: Colors.transparent,
                          width: 2,
                        ),
                  color: _isDragging
                      ? theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.18)
                      : Colors.transparent,
                ),
                padding: const EdgeInsets.all(4),
                child: ObservationPhotosGrid(
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
              children: [
                // Wave 104: gate was director-only (`canManageSpace`)
                // which forced a teacher who fat-fingered an
                // observation to escalate to the director to delete
                // it. New rule: the author OR a director can delete.
                // Audit trail is still preserved server-side
                // (recordedBy is set at create time and never edited).
                if (_isEdit && _canDelete(ref))
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
