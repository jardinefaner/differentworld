import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/family/family_providers.dart';
import 'package:differentworld/features/messages/messages_providers.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/share-home` — **Share from home** (docs/VISION.md 2026-06-19): the
/// family-side half of the homework loop. The phone belongs to the parent; the
/// child never uses it. The kid brings something they saw on TV (or did at
/// home); the parent writes it up and sends it to the teacher, where it
/// surfaces to the room.
///
/// Reuses the proven guardian message-write (`MessageActions.send`) — no new
/// table, no new sync path. The shared moment lands in the child's message
/// thread, tagged so staff see it's from home.
class FamilyShareScreen extends ConsumerStatefulWidget {
  const FamilyShareScreen({super.key});

  @override
  ConsumerState<FamilyShareScreen> createState() => _FamilyShareScreenState();
}

class _FamilyShareScreenState extends ConsumerState<FamilyShareScreen> {
  String? _subjectId;
  final TextEditingController _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send(GuardianViewer viewer, List<Subject> children) async {
    final subjectId =
        _subjectId ?? (children.length == 1 ? children.first.id : null);
    final text = _text.text.trim();
    if (_sending || subjectId == null || text.isEmpty) return;
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(messageActionsProvider)
          .send(
            subjectId: subjectId,
            guardianId: viewer.guardian.id,
            body: '📺 From home: $text',
          );
      if (!mounted) return;
      _text.clear();
      // Programmatic clear doesn't fire the field's onChanged, so rebuild to
      // re-disable the Send button (its gate reads `_text.text`).
      setState(() {});
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Sent to the teacher!')),
        );
    } on Object {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't send — try again.")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final viewer = ref.watch(viewerProvider);
    if (viewer is! GuardianViewer) {
      return const EdgeScaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.home_outlined,
            title: 'For families',
            message: 'Sharing from home is for a child’s parent or guardian.',
          ),
        ),
      );
    }
    final childrenAsync = ref.watch(familyChildrenProvider);

    return EdgeScaffold(
      body: SafeArea(
        child: childrenAsync.when(
          loading: () => const LoadingSlot(),
          // This is the one network-backed family read (PostgREST) — a
          // guardian offline WILL land here, so it needs a retry, and the
          // raw exception never belongs in family-facing copy.
          error: (_, _) => ErrorState(
            title: 'Couldn’t load your children',
            detail: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(familyChildrenProvider),
          ),
          data: (children) {
            if (children.isEmpty) {
              return const EmptyState(
                icon: Icons.home_outlined,
                title: 'No children linked yet',
                message: 'Once your child is linked, you can share from home.',
              );
            }
            final selected =
                _subjectId ?? (children.length == 1 ? children.first.id : null);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const ContentHeader(
                  title: 'Share from home',
                  subtitle: 'Send your child’s teacher a moment from home',
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Text('📺', style: theme.textTheme.headlineSmall),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This week: bring something you saw on TV — then '
                          'tell the class about it.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (children.length > 1) ...[
                  Text('Which child?', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in children)
                        ChoiceChip(
                          label: Text(c.firstName),
                          selected: selected == c.id,
                          onSelected: (_) => setState(() => _subjectId = c.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _text,
                  minLines: 3,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText:
                        'What did they bring? What did they want to share?',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      (_sending ||
                          selected == null ||
                          _text.text.trim().isEmpty)
                      ? null
                      : () => _send(viewer, children),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Send to the teacher'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
