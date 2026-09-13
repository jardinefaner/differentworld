#!/usr/bin/env bash
# Fails on a NEW hand-rolled "whose turn is it" in the diff.
#
# docs/FACILITATION.md rule 2: turn-taking goes through TurnSource. That rule
# was written because FIVE independent answers to "who's up" already existed
# and none of them knew about each other — and because the survey that found
# them initially found only four. It missed rooms/fair_turns.dart for a reason
# worth keeping: that file calls it `nextUp`, and the survey grepped for
# turn-shaped NAMES. So this guard matches a vocabulary, not one word.
#
# The five sanctioned owners stay. They are genuinely different algorithms
# with different correctness conditions (fair bag, side alternation,
# pair-history grouping, term-long fairness) and merging them would destroy
# what each is good at. What is banned is a SIXTH, invented inside a screen.
#
# DIFF-SCOPED, like its siblings: it stops the sprawl growing rather than
# demanding a rewrite of what is already correct. It honours the BASE_REF that
# CI passes — the spacing guard did not, and so ticked green in CI without ever
# reading a line.
set -uo pipefail
cd "$(dirname "$0")/.."

# A declaration — a field, a getter, a local — whose name says "whose go".
PATTERN='(whose_?[Tt]urn|turnIndex|turnHolder|currentPlayer|activePlayer|currentTurn|nextUp|upNext|whoseGo|playerIndex)'

# The role itself, and the four algorithms it wraps.
ALLOW='^(lib/features/facilitation/turn_source\.dart|lib/features/games/grid_game\.dart|lib/features/picker/picker_logic\.dart|lib/features/rooms/fair_turns\.dart|lib/features/rotation/rotation_engine\.dart)$'

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
  echo "$f" | grep -qE "$ALLOW" && continue
  added=$(
    { git diff "$base_ref"...HEAD -- "$f" 2>/dev/null
      git diff -- "$f" 2>/dev/null
      git diff --cached -- "$f" 2>/dev/null
    }
  )
  while IFS= read -r line; do
    body=${line#+}
    # Comments describing the problem are not the problem.
    echo "$body" | grep -qE '^\s*(///|//|\*)' && continue
    # A CALL to a sanctioned owner is the point; a DECLARATION is the defect.
    echo "$body" | grep -qE "$PATTERN\s*(=[^=]|;|\)|,)" || continue
    echo "$body" | grep -qE "(final|var|late|int|String|bool|get)\s" || continue
    echo "  $f: ${body#"${body%%[![:space:]]*}"}"
    bad=1
  done < <(echo "$added" | grep -E '^\+' | grep -v '^+++')
done

if [ "$bad" = 1 ]; then
  echo
  echo "✗ Facilitation: a new hand-rolled turn field."
  echo "  Whose-go goes through TurnSource (lib/features/facilitation/turn_source.dart):"
  echo "    AlternatingSides  two sides, flip on an accepted move"
  echo "    RosterOrder       each child once, in a fixed order"
  echo "    EveryoneOnce      everyone once, the adult picks the order"
  echo "    FairDraw          everyone before anyone repeats"
  echo "    NoTurn            the room acts as one (the honest default)"
  echo "  A genuinely new ALGORITHM is a new TurnSource plus a line in"
  echo "  docs/FACILITATION.md — not a field on a screen."
  exit 1
fi
echo "✓ Facilitation: no new hand-rolled turn fields."
