---
name: edge-to-edge
description: Every screen uses EdgeScaffold (not raw Scaffold + AppBar) so content draws under the transparent status bar and gesture nav. Triggered when adding a new screen.
---

# Edge-to-edge always

The status bar, gesture nav, and any persistent app chrome are transparent.
Content flows from the top of the screen to the bottom; SafeArea only
applies to the top so the user sees their wallpaper / scroll content under
the gesture indicator.

## Use

```dart
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/content_header.dart';

return EdgeScaffold(
  // Home: showBack: false. Drill-in screens: leave default true.
  showBack: false,
  backFallbackRoute: '/settings',  // only if no canPop()
  actions: [
    IconButton(icon: const Icon(Icons.search), onPressed: () => ...),
    const SyncStatusIndicator(),
  ],
  body: ListView(
    padding: const EdgeInsets.only(bottom: 96),  // FAB clearance
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ContentHeader(title: 'Screen title', subtitle: 'Optional'),
      ),
      // ... rest of content
    ],
  ),
  floatingActionButton: FloatingActionButton.extended(...),
);
```

## Never

- `Scaffold(appBar: AppBar(...))` — see also `no-app-bar`
- Raw `Stack` to position back/actions yourself — use the primitives
- `SafeArea(child: ...)` wrapping the entire body — `EdgeScaffold` does
  that already

## Why

The redesign chose iOS-Notes / Things 3 / Linear-style minimal chrome over
Material's persistent AppBar. The shared primitives in
`lib/shared/widgets/` (`edge_scaffold.dart`, `floating_back.dart`,
`floating_actions.dart`, `content_header.dart`, `glass_pill.dart`) keep
every screen consistent.
