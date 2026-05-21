import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/features/tasks/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '_helpers.dart';

/// Tasks screen — empty state. Same rationale as captures_test:
/// loaded state has timestamp drift that doesn't suit goldens.
void main() {
  goldenAtAllBreakpoints(
    'tasks',
    build: () => ProviderScope(
      overrides: [
        tasksProvider(TaskFilter.open).overrideWith(
          (_) => Stream<List<Task>>.value(const <Task>[]),
        ),
        tasksProvider(TaskFilter.all).overrideWith(
          (_) => Stream<List<Task>>.value(const <Task>[]),
        ),
      ],
      child: MaterialApp(
        theme: buildLightTheme(),
        debugShowCheckedModeBanner: false,
        home: const TasksScreen(),
      ),
    ),
  );
}
