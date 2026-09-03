#!/usr/bin/env bash
# Type adherence — BRAND.md law 4, made checkable.
#
# The brand doc says all five visual laws are "shipped and mechanically
# enforced". For COLOUR that was true: a diff-scoped checker, a reviewer agent,
# and a full-codebase scorer. For TYPE there was nothing at all — no script in
# the repo grepped for a font weight, a `.toUpperCase()`, or a font family. So
# type drifted silently, and on 2026-09-03 an audit found 61 themed files
# carrying the Jost-era treatment the brand had already retired: 46 with
# uppercase tracked labels, 25 with w800/w900.
#
# Two rules, both from BRAND.md law 4 ("Two voices of type"):
#
#   1. Sentence case everywhere — no UPPERCASE shouting, whether produced by
#      `.toUpperCase()` or typed in caps as a literal.
#   2. No w800+ weights outside the raw stages.
#
# Reach for `SectionEyebrow` (lib/shared/widgets/section_eyebrow.dart) instead
# of retyping the treatment; that widget exists because sixty-one files had
# nowhere to import it from.
#
# Usage:
#   scripts/check_type_adherence.sh [BASE_REF]
# BASE_REF defaults to origin/main (env BASE overrides). Falls back to HEAD~1,
# then to a full-tree scan if no git history is available.
#
# Diff-scoped like its sibling: it CANNOT see the legacy debt, only new drift.
# The standing backlog is the 61 files above.
#
# Exit 0 = clean. Exit 1 = new type violation in a themed surface.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

BASE="${1:-${BASE:-origin/main}}"

# ── RAW-CANVAS ALLOWLIST ───────────────────────────────────────────────────
# Deliberately the SAME list as check_theme_adherence.sh. A projection stage
# that may hardcode a colour may also shout in caps at w900 — that IS the
# design. Keeping one list means the two guards can never disagree about what
# counts as a raw canvas.
ALLOW='^lib/app/theme\.dart$|^lib/app/design_tokens\.dart$|^lib/features/settings/outdoor_mode_setting\.dart$|_pdf\.dart$|/templates/[^/]+\.dart$|^lib/features/poster/poster_engine\.dart$|^lib/features/poster/poster_screen\.dart$|^lib/features/live_session/cast_cockpit\.dart$|^lib/features/live_session/cast_stage_chrome\.dart$|^lib/features/live_session/cast_receiver\.dart$|^lib/features/live_session/board_screen\.dart$|^lib/features/live_session/live_game_screen\.dart$|^lib/features/live_board/board_game\.dart$|^lib/features/speak/|^lib/features/games/game\.dart$|^lib/features/games/game_stage\.dart$|^lib/features/games/games/|^lib/features/games/game_fullscreen\.dart$|^lib/features/activity_runtime/discussions_screen\.dart$|^lib/features/action_words/world_present_screen\.dart$|^lib/features/action_words/world_cast_game\.dart$|^lib/features/action_words/conductor\.dart$|^lib/features/action_words/widgets/beat_presenter\.dart$|^lib/features/action_words/widgets/present_stage\.dart$|^lib/features/action_words/widgets/block_handoff\.dart$|^lib/features/action_words/reveal_overlay\.dart$|^lib/features/action_words/journey_tour_screen\.dart$|^lib/features/action_words/growth_arc_screen\.dart$|^lib/features/action_words/activity_arc_screen\.dart$|^lib/features/action_words/day_run_screen\.dart$|^lib/features/missions/mission_do_screen\.dart$|^lib/features/activity_runtime/photography_runner_screen\.dart$|^lib/features/activity_runtime/breathe_screen\.dart$|^lib/features/activity_runtime/kid_mode_lock\.dart$|^lib/features/action_words/kid_job_screen\.dart$|^lib/features/action_words/action_words_kid_screen\.dart$|^lib/features/spells/spell_overlay\.dart$|^lib/features/world/draw_self_screen\.dart$|^lib/features/vehicles/guided_capture_screen\.dart$|^lib/features/photos/widgets/multi_shot_camera\.dart$|^lib/shared/widgets/camera_chrome\.dart$|^lib/features/photos/widgets/photo_viewer\.dart$|^lib/features/vehicles/vehicle_scan_screen\.dart$|^lib/shared/widgets/horizon_mark\.dart$|^lib/shared/widgets/generated_portrait\.dart$|^lib/shared/widgets/drawing_pad\.dart$|^lib/features/schedule/block_present_screen\.dart$|^lib/features/story/story_showcase_screen\.dart$|^lib/features/live_session/slide_present\.dart$'

# UPPERCASE shouting: `.toUpperCase()` used on a LABEL. Excludes the
# capitalize-first-letter idioms (`w[0].toUpperCase()`), which are sentence
# case being produced, not abandoned.
UPPER='\.toUpperCase\(\)'
CAPITALIZE='w\[0\]|\[0\]\.toUpperCase|substring\(1\)|input\.toUpperCase'

# Weights heavier than the brand allows on a themed surface.
HEAVY='FontWeight\.(w800|w900)'

# A SHOUTED string literal — 'RIGHT NOW', 'LIVE', 'UP NEXT'. Catching only
# `.toUpperCase()` would miss the most common form by far: the eyebrow typed
# in caps in the first place (`eyebrow: 'RIGHT NOW'` appears four times).
# 4+ chars, so genuine acronyms that ARE the word — PDF, QR, UTC, AM/PM — are
# out of range. Checked against the whole tree when this was written: zero
# technical false positives (no SQL / HTTP / JSON caps literals in lib/).
CAPSLIT="['\"][A-Z][A-Z ]{3,}['\"]"

base_ref=""
if git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
  base_ref="$BASE"
elif git rev-parse --verify --quiet "HEAD~1" >/dev/null 2>&1; then
  base_ref="HEAD~1"
fi

if [ -n "$base_ref" ]; then
  files=$(
    { git diff --name-only --diff-filter=AM "$base_ref"...HEAD -- 'lib/**/*.dart' 2>/dev/null
      git diff --name-only --diff-filter=AM -- 'lib/**/*.dart' 2>/dev/null
      # --cached too: a newly-added file that is staged but not yet committed
      # appears in NEITHER of the two above, so without this a brand-new
      # screen full of violations sails through a pre-commit run.
      git diff --name-only --diff-filter=AM --cached -- 'lib/**/*.dart' 2>/dev/null
    } | sort -u
  )
else
  files=$(find lib -name '*.dart' -type f 2>/dev/null | sort -u)
fi

violations=0
report=""

while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -f "$f" ] || continue
  printf '%s\n' "$f" | grep -qE "$ALLOW" && continue   # raw canvas — skip

  if [ -n "$base_ref" ]; then
    added=$(
      { git diff "$base_ref"...HEAD -- "$f" 2>/dev/null
        git diff -- "$f" 2>/dev/null
        git diff --cached -- "$f" 2>/dev/null
      } | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//'
    )
  else
    added=$(cat "$f")
  fi

  # A trailing `// raw-canvas` exempts one line inside an otherwise-themed
  # file, exactly as the colour guard does — so a mixed file (themed lobby +
  # raw stage) stays checked instead of being allowlisted wholesale.
  clean=$(printf '%s\n' "$added" | grep -v 'raw-canvas')

  upper_hits=$(printf '%s\n' "$clean" | grep -vE "$CAPITALIZE" | grep -nE "$UPPER" || true)
  heavy_hits=$(printf '%s\n' "$clean" | grep -nE "$HEAVY" || true)
  caps_hits=$(printf '%s\n' "$clean" | grep -nE "$CAPSLIT" || true)
  hits=$(printf '%s\n%s\n%s\n' "$upper_hits" "$heavy_hits" "$caps_hits")

  hits=$(printf '%s\n' "$hits" | grep -v '^$' || true)
  if [ -n "$hits" ]; then
    violations=$((violations + 1))
    report="$report
  $f"
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      report="$report
      ${line#*:}"
    done <<< "$hits"
  fi
done <<< "$files"

if [ "$violations" -gt 0 ]; then
  echo "✗ Type-adherence: $violations file(s) add shouted or over-weight type to a themed surface."
  echo "$report"
  echo ""
  echo "Fix: BRAND.md law 4 — sentence case everywhere, no w800+ outside raw stages."
  echo "For the label above a title, use SectionEyebrow"
  echo "(lib/shared/widgets/section_eyebrow.dart) rather than retyping the treatment."
  echo "If this surface is genuinely a raw canvas (print / projection / camera), add"
  echo "its path to the ALLOWLIST in BOTH check_type_adherence.sh and"
  echo "check_theme_adherence.sh in THIS change; a single raw LINE inside an"
  echo "otherwise-themed file takes a trailing // raw-canvas comment instead."
  echo "Contract: docs/BRAND.md law 4"
  exit 1
fi

echo "✓ Type-adherence: no new shouted labels or w800+ weights in themed surfaces."
exit 0
