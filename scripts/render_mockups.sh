#!/usr/bin/env bash
# Render docs/mockups/src/*.html to sibling PNGs.
#
# Chrome headless rather than a Flutter golden: these are PROPOSALS, drawn
# before any Dart existed. Making them depend on the app would mean a
# rejected mockup could no longer be rendered at all, and the rejected ones
# are the point of the archive.
set -euo pipefail
cd "$(dirname "$0")/.."

CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [ ! -x "$CHROME" ]; then
  echo "Chrome not found at: $CHROME" >&2
  echo "Set CHROME=/path/to/chrome and re-run." >&2
  exit 1
fi

src_dir="docs/mockups/src"
out_dir="docs/mockups"
shopt -s nullglob
count=0

for f in "$src_dir"/*.html; do
  base="$(basename "$f" .html)"
  out="$out_dir/$base.png"
  # --window-size is the phone width these were designed against; the pages
  # are in normal flow so the shot captures whatever height they need.
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --screenshot="$out" --window-size=440,1000 \
    --default-background-color=00000000 \
    "file://$PWD/$f" >/dev/null 2>&1
  echo "  rendered $base.png"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "No mockups in $src_dir — nothing to render."
else
  echo "$count mockup(s) rendered into $out_dir/."
fi
