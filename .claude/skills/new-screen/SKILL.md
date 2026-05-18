---
name: new-screen
description: Scaffold a new screen using EdgeScaffold + ContentHeader + the no-nav-bars conventions. Triggered when adding a new screen / route.
---

# /new-screen — scaffold a screen

## Steps

1. Create `lib/features/<feature>/<name>_screen.dart` with the template
   below
2. Register the route in `lib/app/router.dart` (see `new-route` skill)
3. Wire any navigation into it via `context.push` (never `go` for
   drill-in — see `push-not-go`)

## Template

```dart
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FooScreen extends ConsumerWidget {
  const FooScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Replace with the actual data source — Drift stream provider.
    final dataAsync = ref.watch(/* yourProvider */);

    return EdgeScaffold(
      // Drill-in by default (showBack: true). Set false for home pages.
      // backFallbackRoute: '/parent',  // only if reachable from a deep link
      actions: const [
        // Screen-level actions go in the top-right glass pill.
        // SyncStatusIndicator(),
        // IconButton(icon: Icon(Icons.edit_outlined), onPressed: ...),
      ],
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const EmptyState(
          icon: Icons.error_outline,
          title: 'Could not load',
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_outlined,
              title: 'Nothing here yet',
              message: 'Sentence explaining what would go here and how.',
              // action: FilledButton.icon(...),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: items.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: ContentHeader(
                    title: 'Foo',
                    subtitle: 'optional',
                  ),
                );
              }
              return /* tile for items[i - 1] */;
            },
          );
        },
      ),
      // floatingActionButton: FloatingActionButton.extended(...),
    );
  }
}
```

## Checklist for new screens

- [ ] Uses `EdgeScaffold`, not raw `Scaffold + AppBar`
- [ ] Title via `ContentHeader` inside scrollable content
- [ ] All four UX states (loading / empty / error / data)
- [ ] Bottom padding of 96 dp on lists with a FAB
- [ ] All drill-in nav uses `context.push`
- [ ] Haptic feedback on primary taps
- [ ] List uses `ListView.builder` for variable-length lists
