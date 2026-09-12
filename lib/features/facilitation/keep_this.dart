import 'dart:async';

import 'package:differentworld/features/class_memory/class_memory.dart';
import 'package:differentworld/features/class_memory/class_memory_providers.dart';
import 'package:differentworld/features/schedule/live_block_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **What should be remembered afterward** — the sixth facet of the
/// facilitation engine (docs/FACILITATION.md).
///
/// Almost nothing a room did left a trace. `GameDefinition.capture` was
/// declared for exactly this and is **dead**: no game overrides it and nothing
/// reads it, so a round of anything was played and gone. That is the same
/// sentence as the moat — *"we do hundreds of good things with kids and none
/// of it compounds"* — sitting in the codebase as an unused hook.
///
/// This is the cheap half of the fix, and it uses machinery that already
/// works: `ClassMemoryActions.keep` writes an `EntryKind.classMemory` — a
/// thing the ROOM remembers rather than a thing about one child. One tap at
/// the end of an activity turns "we did this" into something that is still
/// there in March.
///
/// **It deliberately keeps the PROMPT, not a transcript.** What a room
/// actually made in Penny or Story Starters is spoken aloud and the app never
/// had it; pretending otherwise would mean asking a counselor to type while
/// thirty children wait. "Our question today was X" is honest, costs one tap,
/// and is the part worth having.
class KeepThisButton extends ConsumerStatefulWidget {
  const KeepThisButton({
    required this.text,
    required this.sort,
    this.context_,
    this.label = 'Keep this',
    super.key,
  });

  /// What to remember, in the room's words.
  final String text;

  final ClassMemorySort sort;

  /// Optional second line — where it came from.
  final String? context_;

  final String label;

  @override
  ConsumerState<KeepThisButton> createState() => _KeepThisButtonState();
}

class _KeepThisButtonState extends ConsumerState<KeepThisButton> {
  bool _saving = false;
  bool _kept = false;

  Future<void> _keep(String groupId) async {
    if (_saving || _kept) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await ref
          .read(classMemoryActionsProvider)
          .keep(
            groupId: groupId,
            sort: widget.sort,
            text: widget.text.trim(),
            context: widget.context_,
          );
      if (mounted) setState(() => _kept = true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Kept — it is in your class memory.')),
        );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Couldn't keep that: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A class memory belongs to a GROUP. Without a live block there is no
    // group to attach it to, so the affordance is not offered — a button that
    // cannot work is worse than no button (CLAUDE.md).
    final groupId = ref.watch(liveBlockProvider)?.groupId;
    if (groupId == null || widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (_kept) {
      return TextButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check, size: 18),
        label: const Text('Kept'),
      );
    }
    return TextButton.icon(
      onPressed: _saving ? null : () => unawaited(_keep(groupId)),
      icon: _saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.bookmark_add_outlined, size: 18),
      label: Text(widget.label),
    );
  }
}
