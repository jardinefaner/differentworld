#!/usr/bin/env bash
# Are the registries actually true?
#
# docs/SCHEMA.md, docs/FEATURES.md and gallery/README.md are only worth
# having if they match the code. They drifted for months because the only
# safety net was a stop-hook NAG — and a nag cannot tell you what is
# missing, and was satisfied by merely touching the file.
#
# This answers the question instead of asking it. Run it by hand, or let
# the stop hook run it (it does).
#
#   scripts/check_registries.sh          # report + exit 1 if anything drifted
#   scripts/check_registries.sh --quiet  # exit code only
#
# Exit 0 = registries match the code. Exit 1 = gaps, listed on stdout.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 0

quiet=0
[ "${1:-}" = "--quiet" ] && quiet=1
say() { [ "$quiet" -eq 1 ] || printf '%s\n' "$*"; }

gaps=0

# ── Synced tables vs docs/SCHEMA.md ──────────────────────────────────────
# Every Drift Table class must have a `## <snake_name>` section.
if [ -f lib/core/db/app_database.dart ] && [ -f docs/SCHEMA.md ]; then
  missing_tables=$(
    grep -oE '^class [A-Za-z]+ extends Table' lib/core/db/app_database.dart |
      awk '{print $2}' |
      sed -E 's/([a-z0-9])([A-Z])/\1_\2/g' | tr '[:upper:]' '[:lower:]' |
      while read -r t; do
        grep -q "^## ${t}$" docs/SCHEMA.md || echo "  $t"
      done
  )
  if [ -n "$missing_tables" ]; then
    gaps=1
    say "docs/SCHEMA.md is missing $(printf '%s' "$missing_tables" | grep -c .) table(s):"
    say "$missing_tables"
    say "  → add a section per the file's own schema (purpose / key columns /"
    say "    RLS gist / sync rule / consumers / last verified)."
    say ""
  fi
fi

# ── Feature folders vs docs/FEATURES.md ──────────────────────────────────
# Matched case-insensitively with underscores as spaces, since the doc uses
# prose headings ("Action Words") for snake folders (action_words).
if [ -d lib/features ] && [ -f docs/FEATURES.md ]; then
  # Strip any parenthetical — the doc uses prose headings like
  # "Curricula (Through My Eyes)" for the folder `curricula`.
  headings=$(grep '^## ' docs/FEATURES.md | sed 's/^## //' |
    sed 's/ *(.*//' | tr '[:upper:]' '[:lower:]' | tr -d ' ')
  missing_features=$(
    for d in lib/features/*/; do
      name=$(basename "$d")
      key=$(printf '%s' "$name" | tr -d '_' | tr '[:upper:]' '[:lower:]')
      printf '%s\n' "$headings" | grep -qx "$key" || echo "  lib/features/$name/"
    done
  )
  if [ -n "$missing_features" ]; then
    gaps=1
    say "docs/FEATURES.md is missing $(printf '%s' "$missing_features" | grep -c .) feature(s):"
    say "$missing_features"
    say "  → add a section with its REAL discovery surfaces (routes / omnibox /"
    say "    slash / drawer / settings). A feature nobody can reach is not shipped."
    say ""
  fi
fi

# ── Shared widgets vs gallery plates (advisory) ───────────────────────────
# Not a failure: some widgets genuinely resist plating (camera, gestures).
# gallery/README.md lists which and why — this just keeps the count honest.
if [ -d gallery ] && [ -f gallery/README.md ]; then
  plates=$(ls gallery/atoms/*__light.png gallery/molecules/*__light.png \
    gallery/organisms/*__light.png 2>/dev/null | wc -l | tr -d ' ')
  screens=$(ls gallery/screens/*__light.png 2>/dev/null | wc -l | tr -d ' ')
  claimed_plates=$(grep -oE '^## Catalogued — [0-9]+ component plates' gallery/README.md |
    grep -oE '[0-9]+' | head -1)
  claimed_screens=$(grep -oE '\+ [0-9]+ screen plates' gallery/README.md |
    grep -oE '[0-9]+' | head -1)
  if [ -n "$claimed_plates" ] && [ "$claimed_plates" != "$plates" ]; then
    gaps=1
    say "gallery/README.md claims $claimed_plates component plates; $plates on disk."
    say ""
  fi
  if [ -n "$claimed_screens" ] && [ "$claimed_screens" != "$screens" ]; then
    gaps=1
    say "gallery/README.md claims $claimed_screens screen plates; $screens on disk."
    say ""
  fi
fi

if [ "$gaps" -eq 0 ]; then
  say "Registries match the code."
  exit 0
fi
say "Update the registries in the SAME WAVE as the code (CLAUDE.md)."
exit 1
