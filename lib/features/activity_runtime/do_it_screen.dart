import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_bank_providers.dart';
import 'package:differentworld/features/entries/entries_providers.dart';
import 'package:differentworld/features/photos/photo_service.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/platform.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

/// `/activity/do-it` — the **"Do It"** activity (docs/VISION.md 2026-06-18).
///
/// One real-world action at a time, big on the room screen: build · find ·
/// move · make · ask · help. The room gets up and DOES it; the teacher taps
/// **We did it!** and — unlike the ephemeral games — it leaves a persistent,
/// accumulating `EntryKind.didIt` record (a room/program entry that stacks into
/// the day + the Book).
///
/// Two ways to mark it done, mapping the user's chosen model:
/// - **Quick tap** ("We did it!") — instant room record, no friction.
/// - **Evidence** ("Snap the proof or tag who led it") — opt-in photo proof
///   (rides the room record) + opt-in per-child "who led it" attributions.
class DoItScreen extends ConsumerStatefulWidget {
  const DoItScreen({this.groupId, super.key});

  /// The cohort doing it, when launched from a room. Null → a program-wide
  /// record (the "room record" still lands; per-cohort scoping is opt-in).
  final String? groupId;

  @override
  ConsumerState<DoItScreen> createState() => _DoItScreenState();
}

class _DoItScreenState extends ConsumerState<DoItScreen> {
  int _index = 0;
  bool _saving = false;
  // The shuffled order is fixed for the session so "Next" always advances to
  // something new (and a re-open re-shuffles). Built lazily from the bank.
  List<ContentItem>? _deck;

  List<ContentItem> _deckFrom(List<ContentItem> items) {
    final existing = _deck;
    if (existing != null) return existing;
    final doIts = items.where((i) => i.kind == ContentKind.doIt).toList()
      ..shuffle();
    _deck = doIts;
    return doIts;
  }

  /// Quick path — instant room record, no photo, no tags.
  Future<void> _markDone(ContentItem item) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ref
          .read(entryActionsProvider)
          .recordDidIt(
            instruction: (item.payload['text'] as String?) ?? '',
            verb: (item.payload['verb'] as String?) ?? 'do',
            groupId: widget.groupId,
          );
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Nice — saved to your record.')),
        );
      _next();
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[do-it] quick save failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save that — try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Rich path — open the evidence sheet, then write the room record (with the
  /// proof photo) plus an opt-in attribution entry per tagged child.
  Future<void> _recordWithEvidence(ContentItem item) async {
    if (_saving) return;
    final evidence = await showGlassSheet<_DoItEvidence>(
      context: context,
      builder: (_) => _DoItEvidenceSheet(groupId: widget.groupId),
    );
    if (evidence == null || !mounted) return;
    // Nothing actually added — treat it as a plain quick tap.
    if (evidence.photo == null && evidence.subjectIds.isEmpty) {
      await _markDone(item);
      return;
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    final instruction = (item.payload['text'] as String?) ?? '';
    final verb = (item.payload['verb'] as String?) ?? 'do';
    try {
      final actions = ref.read(entryActionsProvider);
      // Upload the proof ONCE; it rides the room record. Offline-safe: the
      // deferred-upload queue patches the attachment row whose id == the
      // uploadOnly entityId, so exactly one entry can carry the photo —
      // tagged-child entries are photo-less attributions (the room record is
      // the canonical "this happened").
      var photoUrls = const <String>[];
      var photoIds = const <String>[];
      final photo = evidence.photo;
      if (photo != null) {
        final attId = const Uuid().v4();
        final url = await ref
            .read(photoServiceProvider)
            .uploadOnly(
              entityKind: 'attachment',
              entityId: attId,
              picked: photo,
            );
        photoUrls = <String>[url];
        photoIds = <String>[attId];
      }
      await actions.recordDidIt(
        instruction: instruction,
        verb: verb,
        groupId: widget.groupId,
        photoUrls: photoUrls,
        photoIds: photoIds,
      );
      for (final subjectId in evidence.subjectIds) {
        await actions.recordDidIt(
          instruction: instruction,
          verb: verb,
          groupId: widget.groupId,
          subjectId: subjectId,
        );
      }
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_savedLabel(evidence))));
      _next();
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[do-it] evidence save failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save that — try again.")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _savedLabel(_DoItEvidence e) {
    final parts = <String>[];
    if (e.photo != null) parts.add('photo');
    if (e.subjectIds.isNotEmpty) {
      parts.add('${e.subjectIds.length} tagged');
    }
    return parts.isEmpty
        ? 'Nice — saved to your record.'
        : 'Saved — ${parts.join(' · ')}.';
  }

  void _next() {
    unawaited(HapticFeedback.selectionClick());
    setState(() => _index++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = ref.watch(bankedContentProvider).value ?? curatedSeeds;
    final deck = _deckFrom(items);

    return EdgeScaffold(
      body: deck.isEmpty
          ? const EmptyState(
              icon: Icons.directions_run_outlined,
              title: 'Nothing to do yet',
              message:
                  'Real-world actions will appear here to try with the '
                  'room.',
            )
          : _present(theme, scheme, deck[_index % deck.length]),
    );
  }

  Widget _present(ThemeData theme, ColorScheme scheme, ContentItem item) {
    final text = (item.payload['text'] as String?) ?? '';
    final emoji = (item.payload['emoji'] as String?) ?? '✨';
    final verb = (item.payload['verb'] as String?) ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ContentHeader like every other non-immersive activity, so the
            // whole deck opens the same way — title, subtitle, then content.
            // This screen used a bare `Text('Do it')` in a hand-rolled Row,
            // which is why it read as a different app from Penny or Potions
            // even though the palette and type already matched. The verb chip
            // keeps its place via the header's own `trailing` slot.
            ContentHeader(
              title: 'Do it',
              subtitle: 'One real thing, together',
              bottomGap: 12,
              trailing: verb.isEmpty
                  ? null
                  : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        verb,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            // The action, big — host-present, glanceable across the room.
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A 64pt emoji and a displaySmall headline both double at
                    // 200%; the card is a fixed hero. Loose fit lets the emoji
                    // give way first — the words are the point.
                    Flexible(
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Flexible(
                      child: Text(
                        text,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : _next,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _markDone(item),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('We did it!'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Opt-in evidence path — tertiary so the quick tap stays primary.
            Center(
              child: TextButton.icon(
                onPressed: _saving ? null : () => _recordWithEvidence(item),
                icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                label: const Text('Snap the proof or tag who led it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the evidence sheet returns: an optional proof photo + the children the
/// staff opted to credit. Both empty → caller falls back to a quick tap.
class _DoItEvidence {
  const _DoItEvidence({this.photo, this.subjectIds = const <String>[]});

  final XFile? photo;
  final List<String> subjectIds;
}

/// The opt-in evidence sheet: snap one proof photo + tag who led it.
class _DoItEvidenceSheet extends ConsumerStatefulWidget {
  const _DoItEvidenceSheet({this.groupId});

  final String? groupId;

  @override
  ConsumerState<_DoItEvidenceSheet> createState() => _DoItEvidenceSheetState();
}

class _DoItEvidenceSheetState extends ConsumerState<_DoItEvidenceSheet> {
  XFile? _photo;
  // Decoded once at pick time, NOT in the thumbnail's build — a FutureBuilder
  // future rebuilt on every chip toggle would re-read the file and flash a
  // spinner back over the thumbnail each tap.
  Uint8List? _photoBytes;
  final Set<String> _selected = <String>{};
  bool _picking = false;

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
        _photoBytes = bytes;
      });
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[do-it] photo pick failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add that photo.')),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groupId = widget.groupId;
    final roster = groupId == null
        ? const <Subject>[]
        : ref.watch(subjectsInGroupProvider(groupId)).value ??
              const <Subject>[];

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GlassDragHandle(),
              const SizedBox(height: 8),
              Text('Mark it done', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Add a photo of the proof, and credit who led it. Both are '
                'optional.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _PhotoBlock(
                bytes: _photoBytes,
                picking: _picking,
                onCamera: () => _pick(ImageSource.camera),
                onGallery: () => _pick(ImageSource.gallery),
                onRemove: () => setState(() {
                  _photo = null;
                  _photoBytes = null;
                }),
              ),
              if (roster.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Who led it?', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in roster)
                      FilterChip(
                        label: Text(s.firstName),
                        selected: _selected.contains(s.id),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _selected.add(s.id);
                          } else {
                            _selected.remove(s.id);
                          }
                        }),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _picking
                    ? null
                    : () => Navigator.of(context).pop(
                        _DoItEvidence(
                          photo: _photo,
                          subjectIds: _selected.toList(),
                        ),
                      ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photo affordance inside the evidence sheet: empty → camera + gallery
/// buttons; picked → a thumbnail with a remove action.
class _PhotoBlock extends StatelessWidget {
  const _PhotoBlock({
    required this.bytes,
    required this.picking,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  /// Decoded photo bytes when a proof has been picked; null → show the pickers.
  final Uint8List? bytes;
  final bool picking;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shot = bytes;
    if (shot != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              shot,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Proof added',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(onPressed: onRemove, child: const Text('Remove')),
        ],
      );
    }
    return Row(
      children: [
        // Camera capture is Android/iOS only — image_picker has no live-camera
        // implementation on web OR desktop, so off-mobile we offer only the
        // file picker (matches BrainBreaksScreen's Photo Studio gating).
        if (isMobileCapturePlatform) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: picking ? null : onCamera,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take photo'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: picking ? null : onGallery,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Choose'),
          ),
        ),
      ],
    );
  }
}
