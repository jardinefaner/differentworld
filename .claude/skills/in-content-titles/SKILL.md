---
name: in-content-titles
description: Screen titles live inside the scrollable body via ContentHeader, never in a top chrome bar. Triggered when designing a new screen layout or adding a title.
---

# Titles scroll with the content

The user should see their wallpaper and the system status bar; the title
is the FIRST piece of content they read, and it scrolls away as they
move down the page. iOS Notes / Things 3 / Linear style.

## Use `ContentHeader`

```dart
import 'package:differentworld/shared/widgets/content_header.dart';

ContentHeader(
  title: space?.name ?? 'Today',
  subtitle: 'Saturday, May 17',
  // Default topGap: 56 clears the floating chrome row. Bump if you
  // have stacked floating pills.
)
```

It auto-adds enough top space (56 dp) to clear the floating back +
actions pills that sit at safeAreaTop + 8.

## Wrap correctly in lists

```dart
ListView(
  padding: const EdgeInsets.only(bottom: 96),
  children: [
    const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: ContentHeader(title: '...'),
    ),
    // ... content
  ],
)
```

For `ListView.builder` use the index-0 trick:

```dart
itemBuilder: (_, i) {
  if (i == 0) return ContentHeader(title: '...');
  return YourRow(items[i - 1]);
},
itemCount: items.length + 1,
```

## Don't

- Don't put titles in chrome (AppBar) — that's the whole point of the
  redesign
- Don't add a sticky-header pattern that pins the title — let it scroll
- Don't repeat the title in body content — `ContentHeader` is the header
