import 'package:differentworld/features/child_world/child_world_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ProjectView parses + derives progress / next step', () {
    final p = ProjectView.fromJson(const {
      'week': 3,
      'title': 'Coral reef diorama',
      'steps': ['sketch it', 'paint seaweed', 'add fish', 'name it'],
      'done': 2,
    });
    expect(p.hasProject, isTrue);
    expect(p.total, 4);
    expect(p.doneClamped, 2);
    expect(p.progress, 0.5);
    expect(p.nextStep, 'add fish');
    expect(p.isComplete, isFalse);
  });

  test('a stale done past the step count clamps; complete is derived', () {
    final over = ProjectView.fromJson(const {
      'week': 1,
      'title': 'X',
      'steps': ['a', 'b'],
      'done': 9,
    });
    expect(over.doneClamped, 2);
    expect(over.isComplete, isTrue);
    expect(over.nextStep, isNull);
  });

  test('an empty / stepless project renders nothing meaningful', () {
    final empty = ProjectView.fromJson(const {'week': 1});
    expect(empty.hasProject, isFalse);
    expect(empty.total, 0);
    expect(empty.progress, 0);
    expect(empty.nextStep, isNull);
    expect(empty.isComplete, isFalse);
  });
}
