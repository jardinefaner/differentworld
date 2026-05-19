---
name: file-size
description: When a Dart file is too big. Soft cap 400 lines for screens, 300 for providers, 200 for widgets; hard cap 600 lines for anything single-purpose. Use this when adding to a file that's already heavy.
---

# File size — when to split

Lines are a *symptom*, not the rule. The real rule is: **one file should
hold one cohesive idea you can hold in your head at once.** Lines just
make the smell easier to spot.

## Soft caps (consider splitting)

| File kind | Soft cap | Why |
|---|---|---|
| Screen (route) | 400 | At >400 you're probably embedding widgets that want their own file |
| Providers (`_providers.dart`) | 300 | Split actions class out into its own file, or split by sub-domain |
| Widget | 200 | Widgets are nouns; if it needs >200 it's probably two widgets |
| Drift database root | 200 | Move mutators into `@DriftAccessor` DAOs — see `split-dao` |
| Migration `.sql` | 200 | If you're touching >3 tables in one migration, split into two |
| Freezed model | 100 | Models should be data, not behavior |
| Helper / format module | 100 | Single-purpose, one export typically |

## Hard caps (must split)

- Any single file over **600 lines** is a smell. Either it's two
  features bolted together, or it has private widget classes that
  belong in `widgets/`.
- Any **`app_database.dart`** over **800 lines** — use DAOs.

## When extra lines are OK

- A migration that defines a brand-new domain (table + indexes + RLS +
  policies + publication) legitimately runs ~150 lines. Don't fight it.
- A `survey_take_screen.dart` style "guided flow" where the pages are
  intentionally adjacent for readability. If splitting hurts navigation,
  keep them together.

## How to split (in order of preference)

1. **Pull private widgets into the feature's `widgets/` folder.** Most
   common split. A 700-line screen with three private `_FooCard`,
   `_BarRow`, `_BazSheet` classes becomes a 200-line screen + three
   100-line files in `widgets/`.

2. **Pull the actions class into its own file.** `foo_providers.dart`
   gets too dense when it has streams + family providers + an actions
   class with 10 methods. Move actions → `foo_actions.dart`.

3. **Pull DB mutators into a DAO.** See `split-dao` for the recipe.

4. **Split the feature itself.** If a feature folder has two
   sub-concepts (e.g. `settings/program/` vs `settings/team/`) and the
   provider files are heavy, split the feature folder.

## Don't

- Don't golf for low line counts. A 350-line screen that reads top-to-
  bottom is better than a 200-line screen that imports 6 widget files.
- Don't extract widgets that are used in exactly one place AND have
  fewer than ~40 lines of interesting logic. The indirection costs
  more than it saves.
- Don't split a `_providers.dart` along arbitrary lines — split along
  *concept* lines (read streams in one file, mutations in another).
