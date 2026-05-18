---
name: dont-git-add-dot
description: Never `git add -A` or `git add .`. Stage specific files / dirs by name. The lock-file leak at commit 100fd03 is the cautionary tale.
---

# Stage specifically, never `-A`

`git add -A` sweeps in everything — including Claude session lock files,
half-finished experiments, IDE temp files, and anything your `.gitignore`
doesn't catch yet.

## What happened

Commit `25a728a` accidentally tracked `.claude/scheduled_tasks.lock`
(a per-session pid + start time file). Took commit `100fd03` to clean
up. Pure noise in the history.

## Right

```bash
git add lib/features/photos/ lib/shared/widgets/person_avatar.dart \
        pubspec.yaml supabase/migrations/
git status              # ← always confirm before committing
git commit -m "..."
```

## Wrong

```bash
git add -A
git commit -m "..."
```

## When you do want everything

If you genuinely made a sweeping change across many directories:

```bash
git status              # see what would be added
# ... review carefully ...
git add lib/ pubspec.yaml ios/ android/ supabase/  # specific paths
git status              # confirm before commit
```

Even then, name the paths. Not `.` or `-A`.

## What's at higher risk of leaking

- `.claude/` — session locks, transient state
- `.dart_tool/` — should be gitignored but get re-added if `.gitignore`
  has a hiccup
- `build/` — ditto
- `*.log` — diagnostic dumps
- `.env.local` — never commit env files

`.gitignore` catches most but not all. Specific staging is the second
line of defense.

## Verifying before push

```bash
git log --stat -1   # what does the last commit actually change?
```

If you see surprise files, `git reset HEAD~1`, re-stage properly,
re-commit. Better than pushing surprise files.
