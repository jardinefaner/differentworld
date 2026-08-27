import 'dart:async';
import 'dart:math';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/attendance/present_today.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/photos/photo_consent_providers.dart';
import 'package:differentworld/features/rooms/fair_turns.dart';
import 'package:differentworld/features/rooms/room_events_providers.dart';
import 'package:differentworld/features/subjects/subjects_providers.dart';
import 'package:differentworld/shared/widgets/accent_edge_row.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/person_avatar.dart';
import 'package:differentworld/shared/widgets/person_face_wrap.dart';
import 'package:differentworld/shared/widgets/thumb_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pick someone — fairly (docs/ROTATION.md).
///
/// A generic random picker cannot do this, and not because randomness is
/// hard: it does not know that this child is absent today and that one has
/// already answered twice. Uniform random over a term reliably produces a
/// child who is somehow never chosen. This favours whoever has gone longest
/// without, and writes every pick to the shared room log so the next pick
/// knows about this one.
///
/// One instrument, whole screen, per the half-second rule — and the button
/// you press over and over sits under your thumb.
class TurnsScreen extends ConsumerStatefulWidget {
  const TurnsScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<TurnsScreen> createState() => _TurnsScreenState();
}

class _TurnsScreenState extends ConsumerState<TurnsScreen> {
  String? _picked;
  bool _revealing = false;

  Future<void> _pick(List<Subject> present, Map<String, int> counts) async {
    if (_revealing || present.isEmpty) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _revealing = true);
    final chosen = nextUp(
      presentIds: [for (final s in present) s.id],
      counts: counts,
      rng: Random(DateTime.now().microsecondsSinceEpoch),
    ).firstOrNull;
    // The one place slower is better: an instant answer feels rigged, and
    // this is a fairness claim being made in front of the room.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted || chosen == null) {
      if (mounted) setState(() => _revealing = false);
      return;
    }
    await ref
        .read(roomEventActionsProvider)
        .record(
          groupId: widget.groupId,
          subjectId: chosen,
          kind: RoomEventKinds.picked,
        );
    if (!mounted) return;
    setState(() {
      _picked = chosen;
      _revealing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = (ref.watch(groupsProvider).value ?? const <Group>[])
        .where((g) => g.id == widget.groupId)
        .firstOrNull;
    final roster =
        ref.watch(subjectsInGroupProvider(widget.groupId)).value ??
        const <Subject>[];
    final present = ref.watch(presentSubjectsProvider(widget.groupId));
    final byId = {for (final s in roster) s.id: s};
    // Consent covers being SHOWN, not only being photographed — and this
    // screen is pointed at the room. A declining family's child is picked
    // exactly as often as anyone else; they just appear as initials.
    final defaultAllows = ref.watch(spaceDefaultAllowsPhotosProvider);
    final counts = ref.watch(
      turnCountsProvider((
        groupId: widget.groupId,
        kind: RoomEventKinds.picked,
      )),
    );
    final waiting = [
      for (final s in present)
        if ((counts[s.id] ?? 0) == 0) s,
    ];
    final chosen = _picked == null ? null : byId[_picked];

    return EdgeScaffold(
      backFallbackRoute: '/groups/${widget.groupId}',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    children: [
                      ContentHeader(
                        title: 'Pick someone',
                        subtitle: group == null
                            ? null
                            : '${group.name} · ${present.length} here today',
                      ),
                      if (present.isEmpty)
                        const EmptyState(
                          icon: Icons.touch_app_outlined,
                          title: 'Nobody here to pick',
                          message:
                              'Mark someone present and this knows who to '
                              'choose between.',
                        )
                      else ...[
                        // The reveal slot is a FIXED height whether it is
                        // empty, spinning or filled. Letting it grow would
                        // shove the waiting row down the screen on every
                        // press of a button you press over and over — and
                        // after a re-arrangement the only question anyone
                        // has is what moved.
                        SizedBox(
                          height: 200,
                          child: Center(
                            child: _revealing
                                ? const CircularProgressIndicator()
                                : chosen == null
                                ? const SizedBox.shrink()
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      PersonAvatar(
                                        name: chosen.firstName,
                                        photoUrl: consentedPhotoUrl(
                                          chosen,
                                          defaultAllows: defaultAllows,
                                        ),
                                        radius: 54,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        chosen.firstName,
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.displaySmall,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _turnLabel(counts[chosen.id] ?? 1),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // The reason to use this instead of a wheel app: it
                        // can name who has never been chosen. Faces rather
                        // than a comma list, because matching seven faces
                        // against the room takes a glance and reading seven
                        // names does not.
                        Text(
                          waiting.isEmpty
                              ? 'Everyone here has had a turn.'
                              : 'Still waiting — ${waiting.length} of '
                                    '${present.length}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: waiting.isEmpty
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.primary,
                          ),
                        ),
                        if (waiting.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          PersonFaceWrap(
                            people: [
                              for (final s in waiting)
                                FacePerson(
                                  name: s.firstName,
                                  photoUrl: consentedPhotoUrl(
                                    s,
                                    defaultAllows: defaultAllows,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (present.isNotEmpty)
                  ThumbBar(
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _revealing
                            ? null
                            : () => unawaited(_pick(present, counts)),
                        icon: const Icon(Icons.touch_app_outlined),
                        label: Text(_picked == null ? 'Pick someone' : 'Again'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// No "today" in this label — the room log is not day-scoped, so claiming
  /// it would be a number the screen cannot back up.
  String _turnLabel(int turns) => turns <= 1 ? 'first turn' : 'turn $turns';
}

/// Talk time — who has spoken, and for how long (docs/ROTATION.md).
///
/// One tap starts someone and stops whoever was talking. Two controls for
/// "start" and "stop" would mean looking at the screen, and the whole point
/// is to keep watching the room.
class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  String? _speaking;
  DateTime? _since;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Duration get _current =>
      _since == null ? Duration.zero : DateTime.now().difference(_since!);

  Future<void> _tap(String id) async {
    unawaited(HapticFeedback.selectionClick());
    final was = _speaking;
    final elapsed = _current.inSeconds;
    setState(() {
      _speaking = was == id ? null : id;
      _since = was == id ? null : DateTime.now();
    });
    _tick?.cancel();
    if (_speaking != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
    // Bank whoever just stopped. Anything under two seconds is a mis-tap,
    // not a contribution.
    if (was != null && elapsed >= 2) {
      await ref
          .read(roomEventActionsProvider)
          .record(
            groupId: widget.groupId,
            subjectId: was,
            kind: RoomEventKinds.spoke,
            value: elapsed,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roster =
        ref.watch(subjectsInGroupProvider(widget.groupId)).value ??
        const <Subject>[];
    final totals = ref.watch(talkTotalsProvider(widget.groupId));
    final quiet = silent([for (final s in roster) s.id], totals);

    return EdgeScaffold(
      backFallbackRoute: '/groups/${widget.groupId}',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                const ContentHeader(
                  title: 'Talk time',
                  subtitle: 'Tap whoever is speaking. Tap again to stop.',
                ),
                if (roster.isEmpty)
                  const EmptyState(
                    icon: Icons.record_voice_over_outlined,
                    title: 'Nobody in this room yet',
                    message: 'Add children and this can start listening.',
                  )
                else ...[
                  for (final s in roster)
                    _TalkRow(
                      name: s.firstName,
                      seconds:
                          (totals[s.id] ?? 0) +
                          (_speaking == s.id ? _current.inSeconds : 0),
                      speaking: _speaking == s.id,
                      onTap: () => unawaited(_tap(s.id)),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    quiet.isEmpty
                        ? 'Everyone has said something.'
                        : '${quiet.length} '
                              '${quiet.length == 1 ? 'child has' : 'children have'} '
                              'not spoken yet.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: quiet.isEmpty
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TalkRow extends StatelessWidget {
  const _TalkRow({
    required this.name,
    required this.seconds,
    required this.speaking,
    required this.onTap,
  });

  final String name;
  final int seconds;
  final bool speaking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: AccentEdgeRow(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        accent: speaking ? theme.colorScheme.primary : null,
        title: name,
        trailing: Text(
          talkClock(seconds),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: speaking
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
