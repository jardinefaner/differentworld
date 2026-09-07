import 'dart:async';

import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/game_content/content_kinds.dart';
import 'package:differentworld/features/game_content/our_content.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/destructive_button.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/feature_card.dart';
import 'package:differentworld/shared/widgets/no_access.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// `/library/ours/:kind` — everything this program has written for one kind.
/// Add, edit, remove (with undo). Generated from the kind's spec, so every
/// authorable kind gets this screen without a line of per-kind code.
class OurContentKindScreen extends ConsumerWidget {
  const OurContentKindScreen({required this.kind, super.key});

  final String kind;

  void _open(
    BuildContext context, {
    required ContentKindSpec spec,
    OurContentItem? editing,
  }) {
    // go_router, not Navigator.push: the form is a real route, so its link is
    // shareable and the web back button pops the form rather than the page
    // underneath it.
    final base = '/library/ours/${spec.kind}';
    unawaited(
      context.push(
        editing == null ? '$base/new' : '$base/edit?id=${editing.id}',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(viewerProvider) is GuardianViewer) {
      return const EdgeScaffold(
        body: NoAccess(
          title: 'This is for the team',
          message: "Activity content is written by the program's staff.",
        ),
      );
    }
    final spec = specForKind(kind);
    if (spec == null) {
      return EdgeScaffold(
        body: ErrorState(
          title: "That isn't something you can write",
          detail: 'No form is defined for "$kind".',
        ),
      );
    }
    final itemsAsync = ref.watch(ourContentProvider(spec.kind));
    return EdgeScaffold(
      actions: [
        IconButton(
          tooltip: 'Add a ${spec.one}',
          onPressed: () => _open(context, spec: spec),
          icon: const Icon(Icons.add),
        ),
      ],
      body: itemsAsync.when(
        loading: () => const LoadingSlot(),
        error: (e, _) => ErrorState(
          title: "Couldn't load your ${spec.many}",
          detail: '$e',
          onRetry: () => ref.invalidate(ourContentProvider(spec.kind)),
        ),
        data: (items) => _Body(
          spec: spec,
          items: items,
          onAdd: () => _open(context, spec: spec),
          onEdit: (item) => _open(context, spec: spec, editing: item),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.spec,
    required this.items,
    required this.onAdd,
    required this.onEdit,
  });

  final ContentKindSpec spec;
  final List<OurContentItem> items;
  final VoidCallback onAdd;
  final ValueChanged<OurContentItem> onEdit;

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    OurContentItem item,
  ) {
    final actions = ref.read(ourContentActionsProvider);
    return deleteWithUndo(
      context,
      label: spec.one,
      message: 'Removed “${spec.summarize(item.payload)}”',
      onDelete: () => actions.delete(item.id),
      onUndo: () => actions.restore(item),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Column(
        children: [
          _Header(spec: spec),
          Expanded(
            child: EmptyState(
              icon: spec.icon,
              title: 'None of these are yours yet',
              message: spec.blurb,
              action: FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: Text('Add a ${spec.one}'),
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: items.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return _Header(spec: spec);
        if (i == items.length + 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text('Add a ${spec.one}'),
            ),
          );
        }
        final item = items[i - 1];
        final detail = spec.detail(item.payload);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FeatureCard(
            title: spec.summarize(item.payload),
            subtitle: detail.isEmpty ? null : detail,
            onTap: () => onEdit(item),
            trailing: IconButton(
              tooltip: 'Remove',
              onPressed: () => _remove(context, ref, item),
              icon: Icon(
                Icons.close,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.spec});

  final ContentKindSpec spec;

  @override
  Widget build(BuildContext context) {
    return ContentHeader(title: 'Our ${spec.many}', subtitle: spec.blurb);
  }
}
