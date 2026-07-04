import 'package:differentworld/core/db/power_sync_schema.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the local-index work (2026-06-19 scale wave). PowerSync declares no
/// indexes by default, so a growing table that's watched with
/// `WHERE <owner> … ORDER BY <ts> DESC` full-scans on every emission until
/// someone remembers to add `indexes:`. These tests make "remembering"
/// automatic. See CLAUDE.md "adding a synced table" step 4 + SCALE_PUNCH_LIST.md.
void main() {
  group('PowerSync local schema', () {
    test('the unbounded-growth tables carry hot-query indexes', () {
      final byName = {for (final t in appSchema.tables) t.name: t};
      // These three grow without bound (one row per child per day / per
      // message / per logged moment) and every DAO watch filters + orders by
      // an owner column. They MUST keep their indexes or local reads regress
      // to full scans as history accrues.
      for (final name in const ['entries', 'attendance_records', 'messages']) {
        final table = byName[name];
        expect(table, isNotNull, reason: '$name should be in the schema');
        expect(
          table!.indexes,
          isNotEmpty,
          reason:
              '$name is an unbounded-growth table and must keep its '
              'hot-query indexes (scale — see SCALE_PUNCH_LIST.md)',
        );
      }
    });

    test('every declared index references a real column', () {
      // PowerSync resolves an IndexedColumn against the table's columns only at
      // database-open (a typo throws on launch, not in CI). Catch it here.
      for (final table in appSchema.tables) {
        final columnNames = {'id', for (final c in table.columns) c.name};
        for (final index in table.indexes) {
          for (final column in index.columns) {
            expect(
              columnNames.contains(column.column),
              isTrue,
              reason:
                  'index "${index.name}" on "${table.name}" references '
                  'unknown column "${column.column}"',
            );
          }
        }
      }
    });
  });
}
