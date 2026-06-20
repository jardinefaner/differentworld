import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/schedule/schedule_providers.dart';
import 'package:differentworld/features/schedule/widgets/schedule_slide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ScheduleBlock _block({
  required String kind,
  String? title,
  String startAt = '2026-06-19T14:30:00.000Z',
  String endAt = '2026-06-19T15:15:00.000Z',
}) {
  return ScheduleBlock(
    id: 'b1',
    spaceId: 's1',
    groupId: 'g1',
    date: '2026-06-19',
    startAt: startAt,
    endAt: endAt,
    title: title,
    kind: kind,
    status: BlockStatus.planned,
    createdAt: '2026-06-19T00:00:00.000Z',
    updatedAt: '2026-06-19T00:00:00.000Z',
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ScheduleBlock block,
  required SlidePhase phase,
  Activity? activity,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          // A bounded box stands in for the deck's PageView page so the
          // slide's IntrinsicHeight frame has a viewport to fill.
          body: SizedBox(
            height: 600,
            child: ScheduleSlide(
              block: block,
              activity: activity,
              location: null,
              phase: phase,
              groupId: 'g1',
              canEdit: true,
              canObserve: true,
              onEdit: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Activity _activity(String name) => Activity(
  id: 'a1',
  spaceId: 's1',
  name: name,
  isOutdoor: 0,
  capabilities: '{}',
  createdAt: '2026-06-19T00:00:00.000Z',
  updatedAt: '2026-06-19T00:00:00.000Z',
);

void main() {
  group('ScheduleSlide phase → actions', () {
    testWidgets('a live on-site block acts: attendance + cast + log', (
      tester,
    ) async {
      await _pump(
        tester,
        block: _block(kind: BlockKind.onSite, title: 'Free play'),
        phase: SlidePhase.now,
      );

      expect(find.textContaining('NOW'), findsOneWidget);
      expect(find.text('Free play'), findsOneWidget);
      expect(find.text('Take attendance'), findsOneWidget);
      expect(find.text('Cast to room'), findsOneWidget);
      expect(find.text('Log a moment'), findsOneWidget);
    });

    testWidgets('a finished block stops acting: no attendance, no cast', (
      tester,
    ) async {
      await _pump(
        tester,
        block: _block(kind: BlockKind.onSite, title: 'Morning circle'),
        phase: SlidePhase.done,
      );

      expect(find.textContaining('DONE'), findsOneWidget);
      expect(find.text('Take attendance'), findsNothing);
      expect(find.text('Cast to room'), findsNothing);
      // A finished block can still get a moment logged after the fact.
      expect(find.text('Log a moment'), findsOneWidget);
    });

    testWidgets('a field trip is always actionable (trip tools)', (
      tester,
    ) async {
      await _pump(
        tester,
        block: _block(kind: BlockKind.fieldTrip, title: 'Aquarium'),
        phase: SlidePhase.next,
      );

      expect(find.textContaining('NEXT'), findsOneWidget);
      expect(find.text('Trip tools'), findsOneWidget);
      // Not live yet → no attendance verb, no cast.
      expect(find.text('Take attendance'), findsNothing);
      expect(find.text('Cast to room'), findsNothing);
    });

    testWidgets('a live activity block launches its tool, attendance demotes '
        'to a pill', (tester) async {
      await _pump(
        tester,
        block: _block(kind: BlockKind.onSite, title: 'Math games'),
        phase: SlidePhase.now,
        activity: _activity('Math games'),
      );

      // The primary launches the block's own tool (the /arc runner)…
      expect(find.text('Start the activity'), findsOneWidget);
      // …and attendance is still available, now as a tool pill.
      expect(find.text('Attendance'), findsOneWidget);
      // The generic "Take attendance" primary is gone (the activity won it).
      expect(find.text('Take attendance'), findsNothing);
      // Prep + cast are present on a live block.
      expect(find.text('Prep'), findsOneWidget);
      expect(find.text('Cast to room'), findsOneWidget);
    });
  });
}
