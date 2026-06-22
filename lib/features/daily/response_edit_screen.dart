import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/form_body.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// What the response page returns — a sentence and/or a drawing photo, and
/// optionally the child it belongs to.
class DailyResponse {
  const DailyResponse({
    this.text,
    this.photo,
    this.subjectId,
    this.subjectName,
  });

  final String? text;
  final XFile? photo;

  /// The child this answer belongs to (→ their Book); null → the room answered.
  final String? subjectId;

  /// That child's first name, for the confirmation — null when room-level.
  final String? subjectName;
}

/// `/daily/response` — write a sentence and/or snap a drawing of the answer to
/// the day's Question / Quote / Mission, and (when launched from a cohort) tag
/// whose answer it is.
///
/// Promoted from the `_ResponseSheet` bottom sheet to a route (CLAUDE.md "No
/// modal is a task"): filling a free-text field + attaching a drawing is a
/// task, so it belongs on a deep-linkable page, not a focus-trapping sheet.
/// Saving pops a [DailyResponse] back to the `DailyScreen`, which owns the
/// upload + `recordDailyResponse` persistence.
class ResponseEditScreen extends ConsumerStatefulWidget {
  const ResponseEditScreen({required this.promptText, this.groupId, super.key});

  final String promptText;

  /// The room doing it — when set, the answer can be credited to a child.
  final String? groupId;

  @override
  ConsumerState<ResponseEditScreen> createState() => _ResponseEditScreenState();
}

class _ResponseEditScreenState extends ConsumerState<ResponseEditScreen> {
  final TextEditingController _text = TextEditingController();
  XFile? _photo;
  Uint8List? _bytes;
  bool _picking = false;

  /// Whose answer this is — null means the room answered together.
  Subject? _subject;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await ref.read(photoServiceProvider).pickPhoto(source);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = picked;
        _bytes = bytes;
      });
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[daily] pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that drawing.')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _save() {
    final goRouter = GoRouter.of(context);
    final result = DailyResponse(
      text: _text.text,
      photo: _photo,
      subjectId: _subject?.id,
      subjectName: _subject?.firstName,
    );
    // Pop the response back to DailyScreen, which uploads any photo + writes
    // the daily-response row. A cold deep-link to this page has no back stack —
    // fall back to /daily so a successful save is never a silent no-op.
    if (goRouter.canPop()) {
      goRouter.pop(result);
    } else {
      goRouter.go('/daily');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = _bytes;
    final groupId = widget.groupId;
    final roster = groupId == null
        ? const <Subject>[]
        : ref.watch(subjectsInGroupProvider(groupId)).value ??
              const <Subject>[];
    return EdgeScaffold(
      backFallbackRoute: '/daily',
      body: FormBody(
        children: [
          ContentHeader(title: 'Your response', subtitle: widget.promptText),
          TextField(
            // Stable key: the chip section below can appear once the async
            // roster loads, growing the column — keep this field's Element
            // (and its IME connection) pinned. See "Stack children without
            // keys" in CLAUDE.md.
            key: const ValueKey('daily-response-text'),
            controller: _text,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Write what they said…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (bytes != null)
            Row(
              key: const ValueKey('daily-photo-preview'),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Drawing added')),
                TextButton(
                  onPressed: () => setState(() {
                    _photo = null;
                    _bytes = null;
                  }),
                  child: const Text('Remove'),
                ),
              ],
            )
          else
            Row(
              key: const ValueKey('daily-photo-picker'),
              children: [
                if (isMobileCapturePlatform) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _picking
                          ? null
                          : () => unawaited(_pick(ImageSource.camera)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Snap a drawing'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _picking
                        ? null
                        : () => unawaited(_pick(ImageSource.gallery)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Choose'),
                  ),
                ),
              ],
            ),
          // One keyed child (not a spread) so the async roster appearing
          // inserts a single stable node — no position-shift of the siblings
          // above, which protects the TextField's Element.
          if (roster.isNotEmpty)
            Column(
              key: const ValueKey('daily-whose-response'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Whose response is this?',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('The room'),
                      selected: _subject == null,
                      onSelected: (_) => setState(() => _subject = null),
                    ),
                    for (final s in roster)
                      ChoiceChip(
                        label: Text(s.firstName),
                        selected: _subject?.id == s.id,
                        onSelected: (_) => setState(() => _subject = s),
                      ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),
          // Disabled while a pick is in flight; saving without text OR a
          // drawing is allowed-but-ignored by the caller (it no-ops an empty
          // response), so no required-field gate is needed here.
          FilledButton.icon(
            onPressed: _picking ? null : _save,
            icon: _picking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Save'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}
