import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sync state surfaced in the chrome pill — connected / syncing /
/// offline / error. Rendered as a [SecondaryActionButton] so it
/// matches the height of the primary action in the same row (Wave 18
/// chrome-size normalization).
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(syncStatusProvider);
    final theme = Theme.of(context);

    return statusAsync.when(
      data: (status) {
        final IconData icon;
        final String tooltip;
        final Color color;

        if (!status.connected) {
          icon = Icons.cloud_off_outlined;
          tooltip = 'Offline — changes queued locally';
          color = theme.colorScheme.error;
        } else if (status.downloading || status.uploading) {
          icon = Icons.sync;
          tooltip = status.uploading ? 'Uploading…' : 'Downloading…';
          color = theme.colorScheme.primary;
        } else {
          icon = Icons.cloud_done_outlined;
          tooltip = status.lastSyncedAt == null
              ? 'Connected'
              : 'Synced ${relativeTimeAgo(
                  status.lastSyncedAt,
                  precision: TimePrecision.seconds,
                )}';
          color = theme.colorScheme.primary;
        }

        return SecondaryActionButton(
          tooltip: tooltip,
          icon: icon,
          iconColor: color,
          onPressed: null,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => SecondaryActionButton(
        tooltip: 'Sync error',
        icon: Icons.error_outline,
        iconColor: theme.colorScheme.error,
        onPressed: null,
      ),
    );
  }
}
