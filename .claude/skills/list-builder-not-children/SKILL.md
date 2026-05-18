---
name: list-builder-not-children
description: Use ListView.builder / SliverList for any list that could grow past 10-20 items. Triggered when constructing list UIs.
---

# ListView.builder for anything that can grow

`ListView(children: [...])` builds every child eagerly, even off-screen
ones. Fine for static menus; a frame budget bomb for student rosters,
attendance, observations.

## Right

```dart
ListView.builder(
  padding: const EdgeInsets.only(bottom: 96),
  itemCount: subjects.length,
  itemBuilder: (_, i) => _SubjectTile(subject: subjects[i]),
)
```

## Right for variable / mixed content

When you need a header + a list + a footer, use the `index == 0` /
`index == items.length + 1` trick:

```dart
ListView.builder(
  itemCount: items.length + 1,  // +1 for header
  itemBuilder: (_, i) {
    if (i == 0) return ContentHeader(title: '...');
    return YourRow(items[i - 1]);
  },
)
```

Or `CustomScrollView` with multiple slivers for richer layouts.

## OK to use `ListView(children: [...])`

- Settings screens with a known short list of rows (<10)
- The Today screen has 1 CTA + 1 section header + N classroom cards
  where N is the team's classroom count (typically 1–6); fine

## Never

- `ListView(children: subjects.map(...).toList())` with potentially
  hundreds of items
- `Column(children: items.map(...).toList())` inside a scroll view
