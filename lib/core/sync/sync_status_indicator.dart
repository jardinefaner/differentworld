import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              : 'Synced ${_relative(status.lastSyncedAt!)}';
          color = theme.colorScheme.primary;
        }

        return IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: color),
          onPressed: null,
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => IconButton(
        tooltip: 'Sync error',
        icon: Icon(Icons.error_outline, color: theme.colorScheme.error),
        onPressed: null,
      ),
    );
  }

  String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inSeconds < 30) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
