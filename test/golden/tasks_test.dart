import 'package:differentworld/app/theme.dart';
import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/tasks/tasks_providers.dart';
import 'package:differentworld/features/tasks/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '_helpers.dart';

/// Tasks screen — empty state. Same rationale as captures_test:
/// loaded state has timestamp drift that doesn't suit goldens.
///
/// Hosted in a minimal `GoRouter` (not a bare `MaterialApp`) because
/// `TasksScreen.build` reads `GoRouterState.of(context).uri` for its filter —
/// a plain MaterialApp has no GoRouter ancestor, so the screen threw and the
/// golden never rendered. Any screen that reads `GoRouterState`/`context.go`
/// needs this host.
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
      child: MaterialApp.router(
        theme: buildLightTheme(),
        debugShowCheckedModeBanner: false,
        routerConfig: GoRouter(
          initialLocation: '/tasks',
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (_, _) => const TasksScreen(),
            ),
          ],
        ),
      ),
    ),
  );
}
