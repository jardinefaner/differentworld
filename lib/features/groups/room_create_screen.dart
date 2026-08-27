import 'dart:async';

import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

/// Making a room: ONE field (docs/ROOM_SETUP.md).
///
/// The old create path was the edit form — eleven fields before a room
/// existed, asked at the exact moment you know least about it. Age range,
/// capacity, ratio and skin are all real, and all of them are things you
/// discover in the first week rather than decide before the room exists.
///
/// **Create and Read are different shapes on purpose.** The four operations
/// on a room want four different treatments, and collapsing them into one
/// screen is what made "add a classroom" look nothing like the room it
/// produces:
///
/// - **Create** — one field, then you are standing in it. Here.
/// - **Read** — the room page, `RoomSetupScreen`, everything on one surface.
/// - **Update** — in place on that page. The name is edited where it is
///   displayed; the deeper settings have their own form because they are
///   genuinely a form.
/// - **Delete** — never the default. A room holds children, so the offered
///   verb is CLOSE (reversible, keeps every record); real deletion is behind
///   a cascading confirm.
///
/// Saving pushes you INTO the new room rather than back to a list. You made
/// it because you are about to fill it.
class RoomCreateScreen extends ConsumerStatefulWidget {
  const RoomCreateScreen({super.key});

  @override
  ConsumerState<RoomCreateScreen> createState() => _RoomCreateScreenState();
}

class _RoomCreateScreenState extends ConsumerState<RoomCreateScreen> {
  final _name = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Post-frame, then an explicit IME show — requestFocus alone does not
    // raise the Android keyboard when focus is restored programmatically.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focus.requestFocus();
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final spaceId = ref.read(viewerProvider).spaceId;
    if (name.isEmpty || spaceId == null || _busy) return;

    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = const Uuid().v4();
    try {
      final db = await ref.read(appDatabaseProvider.future);
      await db.groupsDao.create(id: id, spaceId: spaceId, name: name);
      if (!mounted) return;
      // Replace, not push: the empty create form is never somewhere you
      // want to land on back from the room you just made.
      unawaited(router.pushReplacement('/groups/$id'));
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'rooms'),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't make that room. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard the SCREEN, not just the button. Every one of these was
    // reachable by deep link and by search with no check at all, so
    // hiding the entry point was never the same as gating the action.
    if (!ref.watch(viewerProvider).canManageStructure) {
      return const EdgeScaffold(
        backFallbackRoute: '/program',
        body: NoAccess(
          title: 'Only program managers can add rooms.',
          message:
              'A room sets the licensed capacity and ratio it is judged on. Ask whoever runs the program.',
        ),
      );
    }
    final theme = Theme.of(context);
    final labels = ref.watch(verticalLabelsProvider);
    final noun = labels.group.toLowerCase();

    return EdgeScaffold(
      backFallbackRoute: '/program',
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                ContentHeader(
                  title: 'Name the $noun',
                  subtitle: 'You can set everything else up inside it.',
                ),
                TextField(
                  controller: _name,
                  focusNode: _focus,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Call it',
                    hintText: 'Sparrows',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => unawaited(_create()),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _name.text.trim().isEmpty || _busy
                      ? null
                      : () => unawaited(_create()),
                  child: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Make it'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Children, adults and the shape of the day all come next, '
                  'on the $noun itself.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
