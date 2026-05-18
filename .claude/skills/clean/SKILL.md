---
name: clean
description: flutter clean + pub get + (optionally) build_runner. Run when pubspec changed, branches switched, or build behaves strangely.
---

# /clean — flutter clean cycle

```bash
flutter clean && flutter pub get
```

## When

- A pubspec.yaml dependency was added / removed / upgraded
- `git pull` brought in pubspec changes
- Mysterious build errors that don't match the source (cache rot)
- After build_runner crashed or produced a partial regen
- Switching between branches with different Flutter / Dart versions
- New native plugin (share_plus, image_picker, app_links, etc.) added

## Often paired with

```bash
dart run build_runner build --delete-conflicting-outputs
```

When Drift table classes / Freezed / json_serializable annotations changed.

Use `/regen` for the build_runner alone.

## Full reset (when nothing else works)

```bash
flutter clean
rm -rf .dart_tool/ pubspec.lock
flutter pub get
dart run build_runner clean
dart run build_runner build
```

Rarely needed; usually the simpler form does it.
