import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/sync/power_sync_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/shared/format/relative_time.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The sync indicator's tap-through: a glanceable health readout of the
/// local ↔ cloud pipeline. This is where "is it saving?" gets answered
/// without adb — pending local changes, the last upload error, whether
/// this device even has a program yet.
///
/// A glance, not a task (the modals law) — dismiss without acting.

/// Rows waiting in PowerSync's upload queue (`ps_crud`). >0 while offline
/// is NORMAL (offline-first); >0 and growing while connected means uploads
/// are failing — the classic silent-save symptom.
final StreamProvider<int> pendingUploadCountProvider =
    StreamProvider.autoDispose<int>((ref) async* {
      final db = await ref.watch(powerSyncProvider.future);
      yield* db
          .watch('SELECT count(*) AS c FROM ps_crud')
          .map((rows) => (rows.first['c'] as num?)?.toInt() ?? 0);
    });

/// PII-safe local row counts — proves whether this device's database has
/// data at all (an unexpectedly-empty local DB is a re-sync problem, not
/// a save problem).
final StreamProvider<(int, int, int)> _localCountsProvider =
    StreamProvider.autoDispose<(int, int, int)>((ref) async* {
      final db = await ref.watch(appDatabaseProvider.future);
      Future<int> count(String table) => db
          .customSelect('SELECT count(*) AS c FROM $table')
          .getSingle()
          .then((row) => (row.data['c'] as num?)?.toInt() ?? 0);
      yield (
        await count('subjects'),
        await count('groups'),
        await count('entries'),
      );
    });

Future<void> showSyncHealthSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SyncHealthSheet(),
  );
}

class _SyncHealthSheet extends ConsumerWidget {
  const _SyncHealthSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = ref.watch(syncStatusProvider).value;
    final pending = ref.watch(pendingUploadCountProvider).value;
    final counts = ref.watch(_localCountsProvider).value;
    final viewer = ref.watch(viewerProvider);

    final connected = status?.connected ?? false;
    final uploadError = status?.uploadError;
    final downloadError = status?.downloadError;
    final hasSpace = viewer.spaceId != null;

    // The one-line verdict, worst problem first — a staffer shouldn't
    // have to interpret the rows below.
    final (verdictIcon, verdictText, verdictColor) = switch (true) {
      _ when !viewer.isSignedIn => (
        Icons.person_off_outlined,
        'Not signed in — nothing can save.',
        theme.colorScheme.error,
      ),
      _ when !hasSpace && viewer is! GuardianViewer => (
        Icons.home_work_outlined,
        'No program on this device yet — saves are blocked until the '
            'first sync completes.',
        theme.colorScheme.error,
      ),
      _ when uploadError != null => (
        Icons.cloud_upload_outlined,
        'Saves are staying on this device — uploads are failing.',
        theme.colorScheme.error,
      ),
      _ when !connected => (
        Icons.cloud_off_outlined,
        'Offline — saves are safe on this device and will sync '
            'when back online.',
        theme.colorScheme.tertiary,
      ),
      _ when (pending ?? 0) > 0 => (
        Icons.sync,
        'Syncing — ${pending ?? 0} change${pending == 1 ? '' : 's'} '
            'on the way up.',
        theme.colorScheme.primary,
      ),
      _ => (
        Icons.cloud_done_outlined,
        'All good — everything is saved and synced.',
        theme.colorScheme.primary,
      ),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GlassDragHandle(),
            Text('Sync health', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(verdictIcon, color: verdictColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(verdictText, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HealthRow(
              label: 'Connection',
              value: connected ? 'Connected' : 'Offline',
            ),
            _HealthRow(
              label: 'Last synced',
              value: status?.lastSyncedAt == null
                  ? 'Never on this device'
                  : relativeTimeAgo(
                      status!.lastSyncedAt,
                      precision: TimePrecision.seconds,
                    ),
            ),
            _HealthRow(
              label: 'Waiting to upload',
              value: pending == null
                  ? '…'
                  : '$pending change${pending == 1 ? '' : 's'}',
            ),
            if (counts != null)
              _HealthRow(
                label: 'On this device',
                value:
                    '${counts.$1} kids · ${counts.$2} cohorts · '
                    '${counts.$3} entries',
              ),
            if (uploadError != null || downloadError != null) ...[
              const SizedBox(height: 12),
              Text(
                'Last sync error',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 4),
              // Exception payloads can carry row data — full text is
              // debug-only (no-PII law); release gets the type name.
              Text(
                kDebugMode
                    ? '${uploadError ?? downloadError}'
                    : (uploadError ?? downloadError).runtimeType.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
