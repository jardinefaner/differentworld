# Starting simple — onboarding by subtraction

## The problem

| What a new teacher meets on day one | Count |
|---|---|
| Feature folders | 64 |
| Screens | 157 |
| Routes | 413 |
| Nav destinations | 21 |
| Omnibox entries | 116 |
| Slash commands | 39 |

The only orientation the app offered was `create_space` / `join_or_create` /
`sample_child` — account setup. Nothing told anyone what the thing was for.

The failure mode this addresses is **not** "they get lost". It is "they open
it once, feel it is not for them, and stop opening it".

## Why not a tour

CLAUDE.md's instruction hierarchy puts onboarding and help centres **last**:
*the best instruction is the one the user never needs to read*. A tour teaches
21 destination names. This removes the need to learn them.

The rejected alternative was a **reorganisation** — grouping the 64 features
under five outcomes (Safe / Noticed / Heard / Made / Shared). That answers
"how is this organised", which is a different question from "where do I
start", and five abstract nouns is still a taxonomy to learn. It is a real
idea and may still be right for the *impact* question; it is not the answer
to the *onboarding* one.

## What it does

Trims the **navigation** to three destinations plus Settings:

- **Today** — the day, and the route to attendance
- **Observations** — write something down about a child
- **Captures** — the inbox for everything you noticed but could not file yet

## What it must never do

These are load-bearing, and each has a test:

1. **Nothing is deleted, disabled, or revoked.** No data, no route, no
   capability. `buildNavDestinations` filters a list; it does not gate.
2. **Search still reaches all 116 entries.** The omnibox catalogue is
   independent of the nav list, by construction. Search being untouched is
   what makes this a starting point rather than a cage — and it is the
   biggest element in the trimmed drawer for exactly that reason.
3. **Every route stays deep-linkable.** A hidden destination is a statement
   about salience, never permission.
4. **Settings always survives the trim.** A mode you cannot leave from
   inside the UI is a trap.
5. **Capability gates still apply underneath.** `essential` is about
   salience, `onlyFor` is about permission, and permission wins.
6. **It never overrides a choice.** Someone who turned it off is not
   re-trimmed by joining a second program.

## How someone gets it

A settings toggle is not onboarding — the person who most needs it will
never go looking for it. So it is adopted at the one moment the app can be
certain it is looking at a newcomer: **`InviteActions.redeem` succeeding**,
i.e. joining a program you did not create. The director who created the
space never gets it.

`adoptForNewcomer` writes only when the preference has never been set, which
is what makes it safe to fire on every redemption.

Then `StartingSimpleNote` on Today says so once, because a short menu is
otherwise indistinguishable from a broken install. Both of its buttons
retire it for good.

## The bar for `essential`

Deliberately brutal: a destination is essential only if a teacher who has
been here one day would be **worse off without it on screen**. A test pins
the count at three, because the wall comes back one plausible item at a
time and "surely this one too" is always a reasonable-sounding argument.

`YourToolsStrip` is hidden under the trim for the same reason. It is one
collapsed row, which is precisely why it was tempting to keep — and the
person who needs the trim is the person most likely to open the mystery
drawer and land back in all of it.

## Deliberately not done yet

- **Progression.** Nothing yet notices that you have marked attendance all
  week and offers the next tool. Today it is on until you turn it off. That
  progression is the obvious next step and is also where this could most
  easily become condescending — "you've unlocked Photos" is the wrong
  register for a professional tool.
- **Per-device only.** SharedPreferences, consistent with every other
  display preference here. A second device shows the full app, which is the
  safe direction to be wrong in.
