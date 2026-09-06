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
set -uo pipefail
cd "$(dirname "$0")/.."

ALLOWED='^(2|4|8|12|16|24|32)$'
# The scale itself, and gallery/test harnesses that pin exact pixel sizes.
SKIP='^lib/shared/widgets/app_gap\.dart$'

if git rev-parse --verify HEAD >/dev/null 2>&1; then
  RANGE=$(git diff --cached --name-only --diff-filter=AM; git diff --name-only --diff-filter=AM)
else
  RANGE=$(git ls-files 'lib/**/*.dart')
fi

bad=0
for f in $(echo "$RANGE" | sort -u | grep -E '^lib/.*\.dart$'); do
  [ -f "$f" ] || continue
  echo "$f" | grep -qE "$SKIP" && continue
  # Only lines ADDED in the diff, so untouched legacy spacing is not the
  # author's problem.
  added=$(git diff -U0 -- "$f"; git diff --cached -U0 -- "$f")
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
