import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A one-shot handoff for "omnibox composes" — the kind + note the composer
/// parsed, carried into the block editor so it opens pre-filled.
///
/// Why a provider and not a `BlockEditArgs` field: the editor's args record has
/// five construction sites, and `extra` is `Object?`, so adding a field would
/// silently break any site the compiler can't catch. This seed rides alongside
/// the *unchanged* args record instead — the editor reads it once in initState
/// and clears it, so a later plain create never inherits a stale draft.
@immutable
class BlockDraftSeed {
  const BlockDraftSeed({required this.kind, required this.title});

  /// A `BlockKind` constant.
  final String kind;

  /// The parsed subject phrase → the block's note.
  final String title;
}

/// Holds the pending draft between the composer (`set`) and the block editor
/// (`read` + `clear`). Plain `Notifier` per the project convention (no
/// `riverpod_generator`, no `StateProvider`). Nothing *watches* it, so writing
/// it never triggers a rebuild — it's a courier, not reactive state.
class PendingBlockDraft extends Notifier<BlockDraftSeed?> {
  @override
  BlockDraftSeed? build() => null;

  /// The pending draft, if any (mirrors [state] for external readers).
  BlockDraftSeed? get draft => state;

  /// Set the pending draft (or `null` to clear it once consumed).
  set draft(BlockDraftSeed? value) => state = value;
}

final pendingBlockDraftProvider =
    NotifierProvider<PendingBlockDraft, BlockDraftSeed?>(PendingBlockDraft.new);
