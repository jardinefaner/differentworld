#!/usr/bin/env bash
# Theme-adherence guard — the deterministic teeth behind docs/THEME_ADHERENCE.md.
#
# The app has ONE centralized theme (lib/app/theme.dart + design_tokens.dart).
# Hardcoded colors that bypass it are the root cause of the dark/light + contrast
# bugs we keep fixing. This check fails when a CHANGE adds a hardcoded color
# literal to a surface that is supposed to follow the theme.
#
# It is DIFF-SCOPED on purpose: it flags only colors ADDED vs the base ref, so
# the ~750 grandfathered literals (almost all in legitimately-raw surfaces) don't
# block anyone — only NEW bypasses do. Existing files are not retroactively
# punished; new bugs are caught at the door.
#
# A literal is allowed when the file matches the RAW-CANVAS ALLOWLIST below —
# surfaces that deliberately don't follow the screen theme:
#   • print/PDF templates (paper is always white; no screen theme applies)
#   • projection / immersive stages (Present, Cast, Speak, game stages, world-cast)
#   • camera viewfinders (black preview, white controls)
#   • the palette/scheme definitions themselves (theme.dart, design_tokens, outdoor)
# Adding a genuinely-new raw canvas means adding its path here in the SAME PR —
# a visible, reviewable line, not a silent bypass.
#
# Usage:
#   scripts/check_theme_adherence.sh [BASE_REF]
# BASE_REF defaults to origin/main (env BASE overrides). Falls back to HEAD~1,
# then to a full-tree scan if no git history is available.
#
# Portable to bash 3.2 (macOS) and bash 4+ (Ubuntu CI): no mapfile / arrays.
# Exit 0 = clean. Exit 1 = new hardcoded color(s) in a themed surface.

set -uo pipefail
cd "$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

BASE="${1:-${BASE:-origin/main}}"

# ── RAW-CANVAS ALLOWLIST (extended regex over the file path) ────────────────
# Keep tight. Over-allowlisting makes the guard toothless. NOTE game_scaffold /
# game_runner / game_controller are NOT here — their control regions follow the
# theme; only the per-game STAGES (games/games/**) + fullscreen host are raw.
ALLOW='^lib/app/theme\.dart$|^lib/app/design_tokens\.dart$|^lib/features/settings/outdoor_mode_setting\.dart$|_pdf\.dart$|/templates/[^/]+\.dart$|^lib/features/poster/poster_engine\.dart$|^lib/features/poster/poster_screen\.dart$|^lib/features/live_session/cast_cockpit\.dart$|^lib/features/live_session/cast_stage_chrome\.dart$|^lib/features/live_session/cast_receiver\.dart$|^lib/features/live_session/board_screen\.dart$|^lib/features/live_session/live_game_screen\.dart$|^lib/features/live_board/board_game\.dart$|^lib/features/speak/|^lib/features/games/game\.dart$|^lib/features/games/game_stage\.dart$|^lib/features/games/games/|^lib/features/games/game_fullscreen\.dart$|^lib/features/activity_runtime/discussions_screen\.dart$|^lib/features/action_words/world_present_screen\.dart$|^lib/features/action_words/world_cast_game\.dart$|^lib/features/action_words/conductor\.dart$|^lib/features/action_words/widgets/beat_presenter\.dart$|^lib/features/action_words/widgets/block_handoff\.dart$|^lib/features/action_words/reveal_overlay\.dart$|^lib/features/action_words/journey_tour_screen\.dart$|^lib/features/action_words/growth_arc_screen\.dart$|^lib/features/action_words/activity_arc_screen\.dart$|^lib/features/action_words/day_run_screen\.dart$|^lib/features/missions/mission_do_screen\.dart$|^lib/features/activity_runtime/photography_runner_screen\.dart$|^lib/features/activity_runtime/breathe_screen\.dart$|^lib/features/activity_runtime/kid_mode_lock\.dart$|^lib/features/spells/spell_overlay\.dart$|^lib/features/world/draw_self_screen\.dart$|^lib/features/vehicles/guided_capture_screen\.dart$|^lib/features/photos/widgets/multi_shot_camera\.dart$|^lib/shared/widgets/camera_chrome\.dart$|^lib/features/photos/widgets/photo_viewer\.dart$|^lib/features/vehicles/vehicle_scan_screen\.dart$|^lib/shared/widgets/horizon_mark\.dart$|^lib/shared/widgets/drawing_pad\.dart$|^lib/features/schedule/block_present_screen\.dart$|^lib/features/live_session/slide_present\.dart$'

# Solid hardcoded color literals that should instead come from the ColorScheme.
# `Colors.transparent` is theme-neutral; `.withValues(alpha:` overlays/scrims are
# the common legit case (a black scrim under white text over a photo) — both are
# exempt to keep the signal high. Solid fills/text are what break across themes.
NAMED='Colors\.(white|black|red|green|blue|amber|orange|grey|gray|purple|teal|pink|cyan|yellow|indigo|deepPurple|deepOrange|lightBlue|lightGreen|lime|brown|redAccent|greenAccent|blueAccent|amberAccent|pinkAccent|tealAccent|purpleAccent)\b'
HEX='Color\(0x[0-9a-fA-F]{8}\)'

# Resolve a usable base ref.
base_ref=""
if git rev-parse --verify --quiet "$BASE" >/dev/null 2>&1; then
  base_ref="$BASE"
elif git rev-parse --verify --quiet "HEAD~1" >/dev/null 2>&1; then
  base_ref="HEAD~1"
fi

# Collect changed lib/ Dart files (added/modified). No base → scan all of lib/.
if [ -n "$base_ref" ]; then
  files=$(
    { git diff --name-only --diff-filter=AM "$base_ref"...HEAD -- 'lib/**/*.dart' 2>/dev/null
      git diff --name-only --diff-filter=AM -- 'lib/**/*.dart' 2>/dev/null
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
    # Only lines ADDED in the diff (strip the leading '+'), keep them matchable.
    added=$(
      { git diff "$base_ref"...HEAD -- "$f" 2>/dev/null
        git diff -- "$f" 2>/dev/null
      } | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//'
    )
  else
    added=$(cat "$f")
  fi

  # Drop the exempt forms before matching:
  #   • Colors.transparent     — theme-neutral
  #   • .withValues(alpha:     — scrims / overlays (a black scrim over a photo)
  #   • a trailing `// raw-canvas` comment — a single raw line inside an
  #     otherwise-THEMED file (e.g. a presentation stage's dark bg). This is
  #     what lets a MIXED file (themed lobby + raw stage) stay CHECKED while
  #     exempting its raw lines precisely, instead of allowlisting the whole
  #     file (or folder) and blinding the guard to the themed parts.
  hits=$(printf '%s\n' "$added" \
    | grep -vE 'Colors\.transparent|\.withValues\(|raw-canvas' \
    | grep -nE "$NAMED|$HEX" || true)

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
  echo "✗ Theme-adherence: $violations file(s) add a hardcoded color to a themed surface."
  echo "$report"
  echo ""
  echo "Fix: read the color from Theme.of(context).colorScheme (or AppColors), and for"
  echo "a CONTENT-driven fill use AppColors.onAccent(fill) / readableOnDark(accent)."
  echo "If this surface is genuinely a raw canvas (print / projection / camera), add its"
  echo "path to the ALLOWLIST in scripts/check_theme_adherence.sh in THIS change."
  echo "Contract: docs/THEME_ADHERENCE.md"
  exit 1
fi

echo "✓ Theme-adherence: no new hardcoded colors in themed surfaces."
exit 0
