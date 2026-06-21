import 'dart:async';
import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/entries/work_sample_capture.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/shared/widgets/drawing_pad.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:uuid/uuid.dart';

/// The child a role is being practised FOR — threaded into the role card so
/// every artifact tool captures STRAIGHT to that child's cumulative work, with
/// no "which child?" / "what kind?" prompt in between.
typedef RoleSubject = ({String subjectId, String groupId, String subjectName});

/// The three capture modalities a role artifact maps to. Each is ONE tap to a
/// distinct immediate surface — never a generic compose form.
enum RoleToolKind { snap, draw, note }

/// Map an artifact's own wording to its tool (icon + verb + modality). The
/// single source of truth for BOTH the card's tile (display) and the tap
/// action — so the glyph the user sees always matches what the tap does.
({IconData icon, String label, RoleToolKind kind}) roleToolFor(String artifact) {
  final a = artifact.toLowerCase();
  if (a.contains('draw') ||
      a.contains('maze') ||
      a.contains('map') ||
      a.contains('design') ||
      a.contains('sketch')) {
    return (icon: Icons.brush_outlined, label: 'Draw', kind: RoleToolKind.draw);
  }
  if (a.contains('photo') ||
      a.contains('picture') ||
      a.contains('snap') ||
      a.contains('build') ||
      a.contains('make')) {
    return (
      icon: Icons.photo_camera_outlined,
      label: 'Snap',
      kind: RoleToolKind.snap,
    );
  }
  // list / count / record / song / dance / note / everything else → a quick
  // typed note (audio is out of scope for v1, so "record" becomes "describe").
  return (icon: Icons.edit_note_outlined, label: 'Note', kind: RoleToolKind.note);
}

/// How many pieces a child has made while practising a given role (all-time) —
/// counted off the `role` tag every role capture now writes into the
/// work_sample's details. Drives the "practised this N times" growth read on the
/// role card. Derived from the already-watched per-subject stream, so it's free.
// ignore: specify_nonobvious_property_types
final rolePracticeCountProvider = Provider.autoDispose
    .family<int, ({String subjectId, String roleName})>((ref, key) {
      final samples =
          ref
              .watch(
                entriesForSubjectProvider(
                  (subjectId: key.subjectId, kind: EntryKind.workSample),
                ),
              )
              .value ??
          const <Entry>[];
      var n = 0;
      for (final e in samples) {
        final raw = e.details.trim();
        if (raw.isEmpty) continue;
        try {
          if ((jsonDecode(raw) as Map<String, dynamic>)['role'] == key.roleName) {
            n++;
          }
        } on Object catch (_) {
          // Malformed details — skip, don't crash the count.
        }
      }
      return n;
    });

/// Run the artifact's tool IMMEDIATELY for [subject] — one tap, no form. Each
/// result lands as a `work_sample` entry tagged to the child + today's
/// world/day, so it accrues in their cumulative trail (docs/VISION.md — every
/// role ships the tools to practise it; everything captured accumulates).
Future<void> captureRoleArtifact(
  BuildContext context,
  WidgetRef ref, {
  required RoleSubject subject,
  required String artifact,
  required String roleName,
}) {
  switch (roleToolFor(artifact).kind) {
    case RoleToolKind.snap:
      // Immediate camera (gallery off-mobile) → offline-safe work_sample.
      return snapWork(
        context,
        ref,
        subjectId: subject.subjectId,
        groupId: subject.groupId,
        subjectName: subject.subjectName,
        role: roleName,
      );
    case RoleToolKind.draw:
      return _captureDraw(context, subject, roleName);
    case RoleToolKind.note:
      return _captureNote(context, subject, artifact, roleName);
  }
}

/// On-screen drawing → a work_sample. Pushed on the ROOT navigator so the shell
/// chrome doesn't float over the full-bleed canvas (the RevealOverlay pattern).
Future<void> _captureDraw(
  BuildContext context,
  RoleSubject subject,
  String roleName,
) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _RoleDrawScreen(subject: subject, roleName: roleName),
    ),
  );
}

/// A quick typed note → a caption-only work_sample. An autofocused field in a
/// glass sheet; Save commits and pops. No photo, no structured form.
Future<void> _captureNote(
  BuildContext context,
  RoleSubject subject,
  String artifact,
  String roleName,
) {
  return showGlassSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _RoleNoteSheet(subject: subject, prompt: artifact, roleName: roleName),
  );
}

/// Shared save: a caption-only work_sample tagged to the child + world/day +
/// the role being practised.
Future<void> _saveNote(
  WidgetRef ref, {
  required RoleSubject subject,
  required String caption,
  required String role,
}) {
  final world = ref.read(currentWorldProvider);
  final day = ref.read(currentProgramDayProvider);
  return ref
      .read(entryActionsProvider)
      .createWorkSample(
        subjectId: subject.subjectId,
        groupId: subject.groupId,
        caption: caption,
        worldId: world?.id,
        day: day,
        role: role,
      );
}

class _RoleNoteSheet extends ConsumerStatefulWidget {
  const _RoleNoteSheet({
    required this.subject,
    required this.prompt,
    required this.roleName,
  });

  final RoleSubject subject;
  final String prompt;
  final String roleName;

  @override
  ConsumerState<_RoleNoteSheet> createState() => _RoleNoteSheetState();
}

class _RoleNoteSheetState extends ConsumerState<_RoleNoteSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (_saving || text.isEmpty) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    unawaited(HapticFeedback.selectionClick());
    await _saveNote(
      ref,
      subject: widget.subject,
      caption: text,
      role: widget.roleName,
    );
    if (!mounted) return;
    nav.pop();
    messenger?.showSnackBar(
      SnackBar(content: Text("Saved to ${widget.subject.subjectName}'s work")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GlassDragHandle(bottomMargin: 16),
            Text(widget.prompt, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Write it down…',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => unawaited(_save()),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _saving ? null : () => unawaited(_save()),
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleDrawScreen extends ConsumerStatefulWidget {
  const _RoleDrawScreen({required this.subject, required this.roleName});

  final RoleSubject subject;
  final String roleName;

  @override
  ConsumerState<_RoleDrawScreen> createState() => _RoleDrawScreenState();
}

class _RoleDrawScreenState extends ConsumerState<_RoleDrawScreen> {
  final DrawingController _controller = DrawingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_controller.hasDrawing) return;
    setState(() => _saving = true);
    // Cross-pop-safe handles BEFORE any await (the dispatch context dies on pop).
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final service = ref.read(photoServiceProvider);
    final world = ref.read(currentWorldProvider);
    final day = ref.read(currentProgramDayProvider);
    try {
      final png = await _controller.rasterize(pixelRatio);
      if (png == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }
      // The drawing rides the SAME offline-safe path as a snapped photo: a
      // pre-generated attachment id passed to BOTH uploadOnly + createWorkSample
      // (the CLAUDE.md attachment-id contract) so a deferred upload patches the
      // right row offline instead of losing the bytes.
      final attId = const Uuid().v4();
      final xfile = XFile.fromData(
        png,
        mimeType: 'image/png',
        name: 'drawing.png',
      );
      final url = await service.uploadOnly(
        entityKind: 'attachment',
        entityId: attId,
        picked: xfile,
      );
      await ref
          .read(entryActionsProvider)
          .createWorkSample(
            subjectId: widget.subject.subjectId,
            groupId: widget.subject.groupId,
            photoUrls: [url],
            photoIds: [attId],
            worldId: world?.id,
            day: day,
            role: widget.roleName,
          );
      if (!mounted) return;
      nav.pop();
      messenger?.showSnackBar(
        SnackBar(
          content: Text("Saved to ${widget.subject.subjectName}'s work"),
        ),
      );
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'role_draw'),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      messenger?.showSnackBar(
        const SnackBar(content: Text("Couldn't save the drawing — try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Raw full-bleed Scaffold — pushed on the root navigator, so no shell
    // chrome floats over it. The dark canvas matches the draw-self surface.
    return Scaffold(
      backgroundColor: const Color(0xFF2B2A33), // raw-canvas
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel',
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white), // raw-canvas
                  ),
                  Expanded(
                    child: Text(
                      'Draw it for ${widget.subject.subjectName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, // raw-canvas
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: DrawingSurface(controller: _controller),
                  ),
                ),
              ),
            ),
            DrawingTools(controller: _controller, enabled: !_saving),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => FilledButton.icon(
                        onPressed: (_controller.hasDrawing && !_saving)
                            ? () => unawaited(_save())
                            : null,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: const Text('Save to their work'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
