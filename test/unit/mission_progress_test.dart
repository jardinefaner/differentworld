// The mission do-it + save-progress helpers (docs/MISSIONS.md slice 2):
// encode a completion's details JSON, and count completions per mission
// from `entries` rows.

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/missions/mission_progress.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _missionEntry(String details) => Entry(
  id: details.hashCode.toString(),
  spaceId: 'space-1',
  kind: 'mission',
  details: details,
  recordedBy: 'm1',
  recordedAt: '2026-06-01T00:00:00Z',
  updatedAt: '2026-06-01T00:00:00Z',
);

void main() {
  group('encodeMissionCompletion', () {
    test('carries the mission id, name, builds, and step counts', () {
      final json = encodeMissionCompletion(
        missionId: 'mish-1',
        missionName: 'Snack Helper',
        builds: 'service',
        stepsDone: 4,
        stepsTotal: 5,
      );
      final m = jsonDecode(json) as Map<String, dynamic>;
      expect(m['missionId'], 'mish-1');
      expect(m['missionName'], 'Snack Helper');
      expect(m['builds'], 'service');
      expect(m['stepsDone'], 4);
      expect(m['stepsTotal'], 5);
    });

    test('omits an empty builds', () {
      final m =
          jsonDecode(
                encodeMissionCompletion(
                  missionId: 'x',
                  missionName: 'X',
                  builds: '',
                  stepsDone: 0,
                  stepsTotal: 0,
                ),
              )
              as Map<String, dynamic>;
      expect(m.containsKey('builds'), isFalse);
    });
  });

  group('missionCompletionCounts', () {
    test('tallies per missionId', () {
      final entries = [
        _missionEntry(
          encodeMissionCompletion(
            missionId: 'a',
            missionName: 'A',
            stepsDone: 1,
            stepsTotal: 1,
          ),
        ),
        _missionEntry(
          encodeMissionCompletion(
            missionId: 'a',
            missionName: 'A',
            stepsDone: 1,
            stepsTotal: 1,
          ),
        ),
        _missionEntry(
          encodeMissionCompletion(
            missionId: 'b',
            missionName: 'B',
            stepsDone: 1,
            stepsTotal: 1,
          ),
        ),
      ];
      final counts = missionCompletionCounts(entries);
      expect(counts['a'], 2);
      expect(counts['b'], 1);
    });

    test('skips malformed / legacy details', () {
      final counts = missionCompletionCounts([
        _missionEntry('not json'),
        _missionEntry('{"no":"missionId"}'),
        _missionEntry(
          encodeMissionCompletion(
            missionId: 'a',
            missionName: 'A',
            stepsDone: 0,
            stepsTotal: 0,
          ),
        ),
      ]);
      expect(counts, {'a': 1});
    });
  });
}
