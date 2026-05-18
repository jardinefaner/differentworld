---
name: ship
description: Pre-ship checklist for a feature — preflight + analyze + test + relaunch on Pixel. Triggered when the user asks to ship / declare done / commit and push.
---

# /ship — pre-ship checklist

Run these in order. Stop at the first failure.

## 1. Lint clean

```bash
flutter analyze
```

Expect "No issues found!". Fix anything red, even info-level. Don't
suppress lints without a comment explaining why.

## 2. Tests pass

```bash
flutter test
```

The widget test in `test/widget_test.dart` must stay green.

## 3. Preflight

Spawn the **Flutter Preflight** agent on the recently modified files.
It bundles lifecycle / state / async / platform / performance /
security / build / sync checks. Surface any BLOCKER findings before
proceeding.

## 4. Commit

Stage, commit with a focused message (the "why", not the "what"), push.

```bash
git add <specific files>
git commit -m "..."
git push origin main
```

Never use `git add -A` or `git add .` — the lock file leak (commit
`100fd03`) is the cautionary tale.

## 5. Run on Pixel

```bash
flutter run -d adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp
```

If new native deps were added (`share_plus`, `image_picker`, etc.), do
`flutter clean && flutter pub get` first to force the native rebuild.

## When something native changed

Pubspec changes that introduce platform-channel plugins → clean rebuild
required. Manifest / Info.plist changes → clean rebuild required.
Dart-only changes → just relaunch.
