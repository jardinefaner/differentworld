---
name: ship
description: Pre-ship checklist for a feature — analyze + test + Review Council (Preflight + Red Team + UX Critic in parallel + a synthesizer) + relaunch on Pixel. Triggered when the user asks to ship / declare done / commit and push.
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

The widget tests in `test/` AND the goldens in `test/golden/` must
stay green. Update goldens only when the visual change is
intentional, and explain WHY in the commit.

## 3. Review Council

Spawn the **Review Council** agent on the recently modified files.
The Council runs three review tracks IN PARALLEL:

- **Flutter Preflight** — 9 specialist code guards (lifecycle,
  state, async, platform, performance, security, build, flame,
  sync)
- **Red Team** — adversarial review: scenarios where the change
  BREAKS, gets abused, or fails in edge cases (race conditions,
  privilege drift, edge data, offline / sync edge cases, kid-tap
  exploits)
- **UX Critic** — fresh-user review: IA, copy, discoverability,
  flow, density, empty / loading / error states

After the three tracks return, the Council synthesizes them and
looks for CORRELATED BLIND SPOTS — failure modes nobody flagged
on its own but emerge from combining the perspectives. This is
the layer that justifies the council pattern.

**Verdict rules**:

- **SHIP** — no BLOCKERs from any track, no cross-cutting findings
- **FIX FIRST** — 1–3 BLOCKERs or one significant cross-cutting
  finding. Specific, fixable. Address before continuing.
- **NEEDS WORK** — 4+ BLOCKERs, multiple cross-cutting findings,
  or a critical-path coverage gap. Rework needed.

Do not skip Council on "small" changes. The diff size doesn't
predict bug count — the Vehicles-buried-off-screen UX bug from
session `f904bbe` was a single tile-order change that needed
fresh eyes.

## 4. Commit

Stage, commit with a focused message (the "why", not the "what"),
push.

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

If new native deps were added (`record`, `permission_handler`,
`share_plus`, `image_picker`, etc.), do
`flutter clean && flutter pub get` first to force the native rebuild.

If the change touched native manifests (RECORD_AUDIO, photo
permissions, FLAG_SECURE) the install needs a FULL reinstall, not
just hot-reload. Hot-reload won't pick up new platform permissions.

## When something native changed

Pubspec changes that introduce platform-channel plugins → clean
rebuild required. Manifest / Info.plist changes → clean rebuild
required. Dart-only changes → just relaunch.

## QA Gate (optional, for releases)

For a release build (vs personal-dev iteration), also run
**Flutter QA Gate** — the only agent allowed to declare a feature
shippable. It runs the real Flutter toolchain end-to-end (pub get
+ codegen + format + analyze + tests with coverage + apk/ios/web
builds) and refuses to pass if any step fails. Step 3 (Council)
covers correctness + UX before binary; QA Gate covers that the
binary actually builds.
