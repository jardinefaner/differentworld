import 'package:differentworld/features/runtime/noun_rule.dart';

/// The canonical first rule (docs/SEMANTIC_GRAPH.md §1, LIVE_BLOCK_CONTEXT.md):
///
///   WHEN an Entry is created
///   IF a block is live
///   THEN set the entry's scheduleBlockId to the live block's id
///
/// What Wave C of the live-block feature would hardcode, expressed as
/// data. If a block is NOT live, no rule fires and the tag stays null —
/// the design's "null by default, corrected upward, never guessed
/// downward". This is the worked example that proves the runtime; it is
/// not yet wired into the real Entry-create path.
const Rule liveBlockAutoTag = Rule(
  id: 'live-block-auto-tag',
  when: Trigger(nounType: 'Entry', event: 'created'),
  condition: Exists('liveBlock'),
  actions: [
    SetProp(
      targetRef: 'subject',
      path: 'scheduleBlockId',
      fromRef: 'liveBlock',
      fromPath: 'id',
    ),
  ],
);

/// Build the [World] for an Entry-created event: the new entry is the
/// subject; `liveBlock` is the block live at save time (null when none).
/// Mirrors what the real path would assemble from `liveBlockProvider`.
World entryCreatedWorld({
  required String entryId,
  String? liveBlockId,
  Map<String, Object?> entryProps = const {},
}) {
  return World(
    subject: Noun('Entry', entryId, entryProps),
    context: {
      'liveBlock': liveBlockId == null
          ? null
          : Noun('ScheduleBlock', liveBlockId),
    },
  );
}

const Trigger entryCreated = Trigger(nounType: 'Entry', event: 'created');
