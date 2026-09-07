#!/usr/bin/env bash
# Sweep every gallery plate across the screen sizes and text scales the app
# actually ships at, and report every layout overflow with the combination
# that caused it.
#
# WHY THIS EXISTS: each gallery plate hardcodes ONE viewport (mostly 440x900),
# so for a long time "the goldens pass" only ever meant "every screen fits the
# one box its plate was written at". A control bar that overflowed by 280dp at
# 720dp wide, and a stage that overflowed on a short phone, both sat unnoticed
# behind a green suite. STRESS_VIEWPORT re-runs the same plates at another
# size; STRESS_TEXT_SCALE re-runs them at another text scale. This sweeps both.
#
#   scripts/check_overflow_matrix.sh            # the CI grid (fast)
#   scripts/check_overflow_matrix.sh --full     # every size x every scale
#   scripts/check_overflow_matrix.sh --sizes "phone-small,desktop" --scales "2.0"
#
# Exit 0 = no overflow in any combination swept.
set -uo pipefail
cd "$(dirname "$0")/.."

SIZES="phone-small,phone-portrait,phone-landscape,breakpoint-720,desktop"
SCALES="1.0,1.5"
SUITES="test/golden/screens_gallery_test.dart test/golden/game_gallery_test.dart"

while [ $# -gt 0 ]; do
  case "$1" in
    --full)
      SIZES="phone-small,phone-portrait,phone-landscape,breakpoint-600,breakpoint-720,breakpoint-840,tablet-portrait,desktop"
      # 1.3 and 1.5 are the app's OWN "Large" / "Extra large" floors
      # (textScaleSettingProvider), so they are not hypothetical.
      SCALES="1.0,1.3,1.5,2.0"
      SUITES="test/golden/"
      shift ;;
    --sizes) SIZES="$2"; shift 2 ;;
    --scales) SCALES="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

log=$(mktemp -t dw-overflow)
fails=0
combos=0

IFS=',' read -ra SIZE_LIST <<< "$SIZES"
IFS=',' read -ra SCALE_LIST <<< "$SCALES"

for size in "${SIZE_LIST[@]}"; do
  for scale in "${SCALE_LIST[@]}"; do
    combos=$((combos + 1))
    printf '  %-18s x %-4s ... ' "$size" "$scale"
    if RUN_GOLDENS=1 STRESS_VIEWPORT="$size" STRESS_TEXT_SCALE="$scale" \
        flutter test $SUITES > "$log" 2>&1; then
      echo "clean"
    else
      fails=$((fails + 1))
      echo "OVERFLOW"
      # Name the plates, not just the count — a gate that says "something
      # broke" gets muted, and then it protects nothing.
      grep -oE "^[a-z_/]+ - (light|dark)" "$log" | sort -u | head -20 \
        | sed 's/^/      /'
      grep -oE "Layout overflow \([0-9]+\)|overflowed by [0-9]+ pixels on the [a-z]+" "$log" \
        | sort | uniq -c | sort -rn | head -6 | sed 's/^/      /'
    fi
  done
done

rm -f "$log"
echo
if [ "$fails" -eq 0 ]; then
  echo "No overflow in $combos size x scale combinations."
  exit 0
fi
echo "$fails of $combos combinations overflowed."
exit 1
