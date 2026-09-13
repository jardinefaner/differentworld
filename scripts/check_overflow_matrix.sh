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
    # Narrowing the grid must not silently narrow the SUITES too. The default
    # list omits component_gallery_test.dart, so `--sizes phone-landscape`
    # reported "clean" on a combination that --full had just failed — the
    # overflow was in a component plate the default list never renders.
    --suites) SUITES="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

log=$(mktemp -t dw-overflow)
fails=0
others=0
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
    elif grep -qE "overflowed by [0-9]+ pixels|Layout overflow" "$log"; then
      fails=$((fails + 1))
      echo "OVERFLOW"
      # Name the plate, not just the count — a gate that says "something
      # broke" gets muted, and then it protects nothing.
      #
      # Read the FAILING-TESTS block, nothing else. Two earlier attempts were
      # both wrong in instructive ways: the original anchored its pattern to
      # the line start, but `flutter test` prefixes every line with a
      # timestamp and counter, so it printed nothing on every run since it was
      # written. The replacement matched plate names ANYWHERE in the log —
      # which matched the progress lines too, and so listed the first twenty
      # plates alphabetically whether they failed or not. Naming an innocent
      # screen is worse than naming none, because it gets the gate muted.
      sed -n '/^Failing tests:/,$p' "$log" | sed '1d;s/.*\.dart: //' \
        | sort -u | head -20 | sed 's/^/      /'
      grep -oE "Layout overflow \([0-9]+\)|overflowed by [0-9]+ pixels on the [a-z]+" "$log" \
        | sort | uniq -c | sort -rn | head -6 | sed 's/^/      /'
    else
      # A failure with no overflow in it is NOT an overflow, and saying it is
      # makes the whole sweep unbelievable. The --full run reported 32 of 32
      # combinations as overflowing when several were only
      # theme_gallery_test.dart failing an image-SIZE comparison, because it
      # asserted matchesGoldenFile directly and so never honoured isStressRun.
      others=$((others + 1))
      echo "FAILED (not an overflow)"
      sed -n '/^Failing tests:/,$p' "$log" | sed '1d;s/.*\.dart: //' \
        | sort -u | head -6 | sed 's/^/      /'
    fi
  done
done

rm -f "$log"
echo
if [ "$others" -gt 0 ]; then
  echo "$others of $combos combinations failed for a reason that is NOT an overflow."
  echo "  Fix those first — they hide whatever the sweep was meant to find."
fi
if [ "$fails" -eq 0 ] && [ "$others" -eq 0 ]; then
  echo "No overflow in $combos size x scale combinations."
  exit 0
fi
[ "$fails" -gt 0 ] && echo "$fails of $combos combinations overflowed."
exit 1
