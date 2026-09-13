#!/usr/bin/env bash
# Fails on a NEW off-scale spacing literal in the diff.
#
# The app had 29 distinct spacing values across 1,906 SizedBox call sites —
# 2, 3, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 28 … No single one is wrong;
# the problem is that 10 and 12 and 14 all exist, so no two screens share a
# rhythm and the deck reads as assembled rather than designed. That is the
# cause behind "some screens are cramped and not breathable".
#
# DIFF-SCOPED on purpose: the existing 1,900 sites are a staged migration, not
# something to rewrite blind (it would shift every screen's layout at once,
# with 300+ golden plates to re-review). This stops the sprawl GROWING while
# that happens — same shape as check_theme_adherence.sh.
#
# The scale is lib/shared/widgets/app_gap.dart: 2 4 8 12 16 24 32.
#
# It takes a BASE_REF (CI passes the PR base). It used to IGNORE that argument
# and diff the working tree instead — which is always clean on a CI checkout,
# so the guard reported a tick on every run without ever reading a line. Found
# 2026-09-12 while wiring its sibling. If you change how the range is built,
# check it still fails on a deliberately-broken file with a clean tree.
set -uo pipefail
cd "$(dirname "$0")/.."

ALLOWED='^(2|4|8|12|16|24|32)$'
# The scale itself, and gallery/test harnesses that pin exact pixel sizes.
SKIP='^lib/shared/widgets/app_gap\.dart$'

BASE="${1:-${BASE:-origin/main}}"

# Resolve a usable base ref. CI passes the PR base; a local run gets HEAD~1.
base_ref=""
if git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
  base_ref="$BASE"
elif git rev-parse --verify --quiet "HEAD~1" >/dev/null 2>&1; then
  base_ref="HEAD~1"
fi

if [ -n "$base_ref" ]; then
  RANGE=$(
    { git diff --name-only --diff-filter=AM "$base_ref"...HEAD -- 'lib/**/*.dart' 2>/dev/null
      git diff --name-only --diff-filter=AM -- 'lib/**/*.dart' 2>/dev/null
      git diff --name-only --diff-filter=AM --cached -- 'lib/**/*.dart' 2>/dev/null
    } | sort -u
  )
else
  RANGE=$(git ls-files 'lib/**/*.dart')
fi

bad=0
for f in $(echo "$RANGE" | sort -u | grep -E '^lib/.*\.dart$'); do
  [ -f "$f" ] || continue
  echo "$f" | grep -qE "$SKIP" && continue
  # Only lines ADDED in the diff, so untouched legacy spacing is not the
  # author's problem.
  added=$(
      { git diff "$base_ref"...HEAD -- "$f" 2>/dev/null
        git diff -- "$f" 2>/dev/null
        git diff --cached -- "$f" 2>/dev/null
      }
    )
  while IFS= read -r line; do
    px=$(echo "$line" | grep -oE 'SizedBox\((height|width): [0-9]+\)' | grep -oE '[0-9]+' || true)
    [ -z "$px" ] && continue
    for v in $px; do
      if ! echo "$v" | grep -qE "$ALLOWED"; then
        echo "  $f: SizedBox($v) — off the scale (2 4 8 12 16 24 32)"
        bad=1
      fi
    done
  done < <(echo "$added" | grep -E '^\+' | grep -v '^+++')
done

if [ "$bad" = 1 ]; then
  echo
  echo "✗ Spacing: new gaps must use AppGap (lib/shared/widgets/app_gap.dart)."
  echo "  Pick by what the gap is BETWEEN, not by eye:"
  echo "    xs 2   a label and the thing it labels"
  echo "    sm 4   parts of one component"
  echo "    md 8   sibling rows"
  echo "    lg 12  one component and the next"
  echo "    xl 16  groups of components"
  echo "    xxl 24 major blocks"
  echo "    xxxl 32 screen sections"
  exit 1
fi
echo "✓ Spacing: no new off-scale gaps."
