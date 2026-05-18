---
name: regen
description: Run build_runner build to regenerate Drift / Freezed / json_serializable code. Triggered after editing a Drift table or annotated class.
---

# /regen — build_runner build

```bash
dart run build_runner build --delete-conflicting-outputs
```

## When to run

- After editing a class in `lib/core/db/app_database.dart`
  (Drift Tables, `@DriftDatabase`)
- After editing a `@freezed` class
- After editing a `@JsonSerializable` class

## If build_runner says "wrote 0 outputs" but source changed

Cache lying. Force a full regen:

```bash
dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs
```

## After regen, before commit

```bash
flutter analyze
```

Codegen mismatches show up here. Check that no `.g.dart` files were
generated outside `lib/` (drift_dev sometimes generates stray ones —
delete and re-run if so).

## The git pattern

`.g.dart` files ARE checked in (they're part of the build). Commit them
alongside the source change so other devs / CI don't have to regenerate.
