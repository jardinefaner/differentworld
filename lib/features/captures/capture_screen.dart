import 'dart:async';

import 'package:differentworld/features/captures/captures_providers.dart';
import 'package:differentworld/features/photos/attachments_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/photos/widgets/person_photo_network.dart';
import 'package:differentworld/features/photos/widgets/photo_viewer.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:differentworld/features/settings/bento_everywhere_setting.dart';
import 'package:differentworld/features/voice/deepgram_voice_service.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// Drop a quick "I noticed…" into the capture inbox.
///
/// Promoted from `capture_sheet.dart` (bottom-sheet) to a full
/// route at `/captures/new` in Wave 21. Routes give the form full
/// chrome, proper back button, and the layout law — no more cramped
/// modal feel.
///
/// **Auto-save semantics preserved.** Every keystroke schedules a
/// serialized save through a `Future` chain. The first non-empty
/// character INSERTs the capture row; subsequent edits UPDATE it.
/// If the user navigates away with an empty body, the shell row is
/// discarded so the inbox stays tidy. In-flight writes complete in
/// the background even after the widget unmounts (the chain
/// references the captured actions instance, not `ref`).
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Actions instance captured at mount so the save chain can
  /// complete safely after the widget is gone.
  late final CaptureActions _actions;

  /// Serialized chain of write Futures. Each keystroke appends a
  /// `.then(...)` so writes happen in typed order.
  Future<void> _saveChain = Future<void>.value();

  /// The id of this capture's row, after the first non-empty save.
  /// Subsequent saves UPDATE this row.
  String? _captureId;

  /// URLs (Storage paths or `pending:` tokens) of photos attached to
  /// this capture, in attach order. Drives the inline thumbnail strip.
  /// A capture carrying any photo is NON-EMPTY — `dispose`'s discard
  /// guard checks this so a photo-only capture is never thrown away.
  List<String> _photos = const [];

  /// True while a compress+upload is in flight, so the camera button
  /// shows a spinner and re-taps are ignored.
  bool _photoUploading = false;

  /// True while a save round-trip is in flight, so the "Saved" chip
  /// can flash green.
  bool _savedFlash = false;
  Timer? _flashTimer;

  // -- Voice dictation (Jordan / Brianna; persona-audit 2026-05-23) --
  //
  // Floor-use persona: counselor mid-cohort, one hand on a clipboard,
  // wants to dump a thought before it falls out. Same pattern as the
  // observation form — a FORM-LOCAL DeepgramVoiceController (NOT the
  // AppShell singleton) so dictation here can't fight with a session
  // already running on the omnibox bar. Auto-save listener still
  // catches every transcript update because dictation writes through
  // `_ctrl.text`, which triggers `_onChanged` exactly like typing.
  late final DeepgramVoiceController _voice;
  StreamSubscription<VoiceUpdate>? _voiceSub;
  bool _voiceActive = false;
  String _voicePrefix = '';

  @override
  void initState() {
    super.initState();
    _actions = ref.read(captureActionsProvider);
    _voice = DeepgramVoiceController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _ctrl.removeListener(_onChanged);
    // Tear down voice first so a late transcript can't land in
    // `_ctrl` after dispose. Then the underlying recorder / WS.
    unawaited(_voiceSub?.cancel());
    _voiceSub = null;
    unawaited(_voice.dispose());
    // If the user opened the screen, never typed anything meaningful,
    // attached NO photo, and navigated away — hard-delete the shell row
    // so the inbox stays tidy. A photo-only capture is NON-EMPTY, so the
    // `_photos.isEmpty` guard keeps it (without it, `discardEmpty` would
    // wipe a capture whose only content is a snapped photo — orphaning
    // the attachment row). Capture `id`/`_photos` here because
    // `this._captureId` may be read by the chain after super.dispose().
    final id = _captureId;
    final lastText = _ctrl.text;
    final hasPhoto = _photos.isNotEmpty;
    if (id != null && lastText.trim().isEmpty && !hasPhoto) {
      _saveChain = _saveChain.then((_) => _actions.discardEmpty(id));
    }
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Toggle Deepgram dictation for the body field. Mirrors the
  /// observation form: snapshot whatever the user typed before the
  /// session starts, append the live transcript as it streams in.
  /// Auto-save fires through `_onChanged` for free.
  void _toggleVoice() {
    if (_voiceActive) {
      unawaited(_voice.stop());
      return;
    }
    _voicePrefix = _ctrl.text;
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
    _ctrl
      ..text = combined
      ..selection = TextSelection.collapsed(offset: combined.length);
    if (update.state == VoiceState.idle) {
      _voiceActive = false;
      unawaited(_voiceSub?.cancel());
      _voiceSub = null;
      setState(() {});
    }
  }

  void _onChanged() {
    // Capture the current text NOW; never read `_ctrl` inside the
    // chain (it could be disposed by then).
    final text = _ctrl.text;
    _saveChain = _saveChain.then((_) => _doSave(text));
  }

  Future<void> _doSave(String text) async {
    try {
      if (_captureId == null) {
        if (text.trim().isEmpty) return; // nothing to persist yet
        // `??=`, not `=`: a camera tap's `_ensureCaptureId` may have
        // created the row between this save being queued and running
        // (both chain on `_saveChain`, so they're sequential — but the
        // symmetric `??=` makes "first writer wins" hold structurally,
        // not by argument order, so neither path ever creates a 2nd row).
        _captureId ??= await _actions.start(body: text);
      } else {
        await _actions.updateBody(id: _captureId!, body: text);
      }
      if (!mounted) return;
      _flashSaved();
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'captures'),
      );
    }
  }

  void _flashSaved() {
    setState(() => _savedFlash = true);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _savedFlash = false);
    });
  }

  /// Guarantee the capture row exists and return its id, WITHOUT
  /// racing the auto-save chain. Routed through `_saveChain` so a
  /// keystroke-save and a camera tap can't both call `start` and
  /// create two rows — whichever runs first sets `_captureId`, the
  /// other sees it set. The body may still be empty (photo-first
  /// capture); `start` accepts that.
  Future<String> _ensureCaptureId() {
    final op = _saveChain.then((_) async {
      _captureId ??= await _actions.start(body: _ctrl.text);
      return _captureId!;
    });
    // Keep the chain alive even if this op throws, so later keystroke
    // saves still run; the caller (`_addPhoto`) still sees the error.
    _saveChain = op.then((_) {}).catchError((Object _) {});
    return op;
  }

  /// Snap (mobile) or pick (web/desktop) a photo, upload it offline-
  /// safe, and attach it to this capture. Follows the stable-id
  /// contract: the attachment id is pre-generated and passed to BOTH
  /// `uploadOnly(entityId:)` AND `attachments.add(id:)`, so a deferred
  /// (offline) upload's queue-side `updateUrl(id)` patches the SAME
  /// row instead of silently losing the photo.
  Future<void> _addPhoto() async {
    if (_photoUploading) return;
    final service = ref.read(photoServiceProvider);
    final attachments = ref.read(attachmentActionsProvider);
    // The block live RIGHT NOW — but ONLY when it's unambiguous which room it
    // belongs to (exactly one of the viewer's cohorts is live). A capture has
    // no cohort picker, so stamping the cross-room "most-recently-started"
    // winner could flow a photo to the WRONG cohort's families (a director with
    // two live rooms). When two-plus rooms are live this is null → the photo
    // stays a plain inbox capture (block null), never auto-distributed. Single
    // live room → certain stamp → it flows to that one cohort's recap. ref.read
    // at photo time (not watch); see unambiguousLiveBlockProvider.
    final liveBlock = ref.read(unambiguousLiveBlockProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Camera on mobile; a file/gallery pick everywhere else — no in-app
    // camera off-mobile (docs/PLATFORM_RUBRIC.md P1), same gate the
    // observation + work-sample flows use.
    final source = isMobileCapturePlatform
        ? ImageSource.camera
        : ImageSource.gallery;
    final XFile? picked;
    try {
      picked = await service.pickPhoto(source);
    } on Exception catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'captures'),
      );
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Could not open the camera.')),
      );
      return;
    }
    if (picked == null) return; // user backed out of the picker
    if (!mounted) return;
    setState(() => _photoUploading = true);
    unawaited(HapticFeedback.mediumImpact());
    try {
      // Create the row up front so a photo-first capture (no typed text)
      // has something to attach to. Serialized with auto-save.
      final captureId = await _ensureCaptureId();
      final attId = const Uuid().v4();
      final url = await service.uploadOnly(
        entityKind: 'attachment',
        entityId: attId,
        picked: picked,
      );
      await attachments.add(
        id: attId,
        entityKind: 'capture',
        entityId: captureId,
        url: url,
        // Stamp the live block so the photo is queryable by block (the recap
        // gathers a day's block photos). A capture has no subject picker, so
        // subjectId stays null — a room moment, shown to every family of the
        // cohort, never tagged to one child.
        scheduleBlockId: liveBlock?.blockId,
      );
      if (!mounted) return;
      setState(() => _photos = [..._photos, url]);
      _flashSaved();
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'captures'),
      );
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text("Couldn't save that photo. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // "Bento everywhere" for forms = a toggle-gated responsive 2-column
    // field layout. Capture is essentially ONE long note field, so there's
    // nothing to pair — when bento is on we just give the single column a
    // touch more breathing room (720 vs the 600 default). No fake columns.
    final bento = bentoEnabled(ref, perScreen: null);
    return EdgeScaffold(
      backFallbackRoute: '/captures',
      body: FormBody(
        maxWidth: bento ? 720 : 600,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: ContentHeader(
                  title: 'Capture',
                  subtitle: 'What did you notice?',
                  bottomGap: 0,
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _savedFlash ? 1 : 0,
                child: Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  label: const Text('Saved'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            focusNode: _focus,
            autofocus: true,
            minLines: 6,
            maxLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: "Drop a thought. We'll auto-save as you type.",
              helperText: _voiceActive ? 'Listening…' : null,
              border: const OutlineInputBorder(),
              // Mic sits as the suffix so it lives next to the text it
              // dictates into. Tapping toggles a live Deepgram session;
              // the transcript appends to whatever the user typed,
              // and auto-save catches it through `_onChanged`.
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
          const SizedBox(height: 12),
          // Photo affordance — answers the flag "what if I want to take
          // pictures instead." A photo-only capture is valid: the camera
          // button creates the row up front, so you can snap without
          // typing a word. The thumbnail strip shows what's attached.
          _PhotoStrip(
            photos: _photos,
            uploading: _photoUploading,
            onAdd: _addPhoto,
            onView: (i) => PhotoViewer.open(
              context,
              urls: _photos,
              initialIndex: i,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Saves to the inbox automatically. Triage later from '
            '/captures or the weekly review. Empty captures are '
            'discarded when you leave.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  if (context.canPop()) context.pop();
                },
                icon: const Icon(Icons.check),
                label: const Text('Done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "add a photo" affordance + the thumbnails already attached.
/// A leading tile (camera on mobile, library elsewhere) opens the
/// picker; each thumbnail opens the full-screen viewer. Lives inline
/// under the note field so the photo path is as obvious as typing —
/// the answer to "what if I want to take pictures instead."
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.uploading,
    required this.onAdd,
    required this.onView,
  });

  final List<String> photos;
  final bool uploading;
  final VoidCallback onAdd;
  final ValueChanged<int> onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Mobile gets a camera glyph (in-app camera); web/desktop falls back
    // to a library/add glyph since there's no reliable camera there.
    final addIcon = isMobileCapturePlatform
        ? Icons.photo_camera_outlined
        : Icons.add_photo_alternate_outlined;
    final addLabel = isMobileCapturePlatform ? 'Photo' : 'Add photo';
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Add tile.
          Semantics(
            button: true,
            label: addLabel,
            child: InkWell(
              onTap: uploading ? null : onAdd,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                  color: scheme.surfaceContainerHighest,
                ),
                child: uploading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(addIcon, color: scheme.primary),
                          const SizedBox(height: 2),
                          Text(
                            addLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          for (var i = 0; i < photos.length; i++) ...[
            const SizedBox(width: 8),
            GestureDetector(
              // Opaque so the tap stays live even before the image loads.
              behavior: HitTestBehavior.opaque,
              onTap: () => onView(i),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: PersonPhotoNetwork(
                    urlOrPath: photos[i],
                    errorBuilder: (_) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
