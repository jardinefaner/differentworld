---
name: feature-folder
description: The canonical layout for `lib/features/<feature>/`. Use when starting a new feature or wondering where a file goes.
---

# Feature folder layout

Every feature lives under `lib/features/<noun>/`. The noun is
**plural** if the feature is about a collection (subjects, vehicles,
captures), singular if it's about a single concept (today, auth,
onboarding).

## Canonical files

```
lib/features/<feature>/
  <feature>_providers.dart      ← Riverpod streams + Actions class
  <feature>_screen.dart         ← the primary route (`/<feature>`)
  <feature>_detail_screen.dart  ← optional, when there's an item view
  <feature>_edit_screen.dart    ← optional, when there's an edit view
  widgets/                       ← UI pieces used only by this feature
    <feature>_card.dart
    <feature>_form.dart
  models/                        ← Dart types beyond the Drift row
    <feature>_filter.dart        ← (only when the row type isn't enough)
```

## Files DO NOT go here

- **Drift tables** → `lib/core/db/app_database.dart` (or a DAO under
  `lib/core/db/dao/` — see `split-dao`)
- **Shared widgets** (used by 2+ features) → `lib/shared/widgets/`
- **Pure formatters** → `lib/shared/format/`
- **Capabilities / permissions logic** → `lib/core/capabilities/`
- **Routes** → register in `lib/app/router.dart`

## Picking names

- Files: `snake_case.dart`
- Classes: `PascalCase` (Drift convention)
- Providers: `camelCase` ending in `Provider`
- Actions class: `<Feature>Actions` (singular concept, even if folder
  is plural)

## Example — surveys

```
lib/features/surveys/
  survey_templates.dart            ← Dart-defined templates (constants)
  surveys_providers.dart           ← surveyResponsesProvider, SurveyActions
  survey_list_screen.dart          ← /surveys
  survey_take_screen.dart          ← /surveys/:templateId/take/:subjectId
  widgets/
    chibi_smiley.dart              ← used only here
```

## Don't

- Don't make a feature folder for a single screen with no other
  collaborators. Inline it next to a related feature (`auth/login_screen.dart`
  is fine; `auth/` doesn't need a `widgets/` folder).
- Don't put a generic widget (used by 2+ features) inside one feature's
  `widgets/` folder. Move it to `lib/shared/widgets/`.
- Don't bypass `router.dart` with `Navigator.push(MaterialPageRoute(...))`.
  Every route is registered in one place (see `new-route`).
