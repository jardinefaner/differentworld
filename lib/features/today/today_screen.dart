import 'package:differentworld/core/sync/sync_status_indicator.dart';
import 'package:differentworld/core/vertical/labels.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/groups/groups_providers.dart';
import 'package:differentworld/features/onboarding/widgets/starter_spine.dart';
import 'package:differentworld/features/today/widgets/today_sections.dart';
import 'package:differentworld/shared/widgets/async_loading.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:differentworld/shared/widgets/error_state.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/responsive_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Home screen: "what's happening today across my classrooms."
///
/// Thin shell — composes [TodayBody] (which lives in
/// `widgets/today_sections.dart` alongside every per-section widget
/// the body renders). The body holds the layout + section ordering;
/// this file owns the chrome + loading / empty / error states.
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  @override
  Widget build(BuildContext context) {
    final viewer = ref.watch(viewerProvider);
    final labels = ref.watch(verticalLabelsProvider);
    final member = viewer.member;
    final space = viewer.space;
    final groupsAsync = ref.watch(groupsProvider);

    return EdgeScaffold(
      // Today is a home page → no back button, just the hamburger.
      // Search affordance is the global one injected by EdgeScaffold.
      // (Wave 101: dropped `drawer: const MainDrawer()`. The param
      // is documented as ignored — AppShell owns the drawer for every
      // signed-in route. Passing it here was misleading.)
      showBack: false,
      actions: [
        // Primary verb on Today is "Capture" — what used to be the
        // bottom-right FAB lives here so the bottom of the screen is
        // free for the omnibox bar.
        if (groupsAsync.value?.isNotEmpty ?? false)
          PrimaryActionButton(
            tooltip: 'Capture',
            icon: Icons.bolt_outlined,
            onPressed: () => context.push('/captures/new'),
          ),
        const SyncStatusIndicator(),
      ],
      body: groupsAsync.when(
        loading: () => const LoadingSlot(variant: LoadingVariant.cards),
        error: (_, _) => ErrorState(
          title: 'Could not load today',
          onRetry: () => ref.invalidate(groupsProvider),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            // Day one: the director gets the starter spine — the app
            // proving itself — instead of a bare empty state.
            if (viewer.canManageSpace) {
              return ResponsivePage(
                children: [
                  ContentHeader(
                    title: space?.name ?? 'Today',
                    subtitle: 'Day one.',
                  ),
                  const StarterSpine(),
                ],
              );
            }
            final groupsLower = labels.groupPlural.toLowerCase();
            return EmptyState(
              icon: Icons.meeting_room_outlined,
              title: 'No $groupsLower yet',
              message:
                  'Your director will set up $groupsLower here. '
                  'Check back later.',
            );
          }
          return TodayBody(
            member: member,
            groups: groups,
            space: space,
            viewer: viewer,
          );
        },
      ),
    );
  }
}
