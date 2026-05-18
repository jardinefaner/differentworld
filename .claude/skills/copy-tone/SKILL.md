---
name: copy-tone
description: How to write user-facing copy in this app — direct, specific, action-oriented, no hedging. Triggered when writing button labels, empty states, dialog text, snackbars.
---

# Copy tone

Teachers and directors don't have time for friendly chatter. Every
string earns its place.

## Rules

- **Imperative verb-noun for actions**: "Add student", "Remove from
  team", "Mark all present" — not "Click here to add a student"
- **No hedging**: not "It seems you might want to…", just "Discard
  changes?" with Yes/No
- **Sentence case**: "Pending invites", not "PENDING INVITES" except
  for tight section labels (where we DO uppercase a 1-2 word label
  with letter-spacing 0.6 — see `_SectionLabel`)
- **Plain English**: "Removing Jane lets her keep her account but she
  loses access to this program." not "This action will revoke the
  user's permissions for the current organizational entity."
- **Specific over generic**: "We couldn't find that invite. Double-check
  the code with your director." not "An error occurred."

## Naming the action in dialogs

The confirm button in a destructive dialog says what it does — never
just "Yes" or "OK":

```dart
confirmDestructive(
  context,
  title: 'Remove Jane?',
  message: '...',
  confirmLabel: 'Remove from team',  // verb + noun
)
```

## Empty state copy

| Element | Voice |
|---|---|
| Title | Single sentence, factual ("No students yet") |
| Message | Two sentences max, what would be here + what to do |
| Action button | Imperative verb-noun ("Add student") |

## Snackbar copy

- Success: past tense, brief ("Photo updated.", "Invite revoked")
- Error: brief + suggest next step ("Could not upload. Try again.")
- Undo: include the Undo action; don't make the user navigate

## What to avoid

- Exclamation marks (one is OK in a celebration moment; "Everyone is
  marked!" is fine)
- "Please" / "Sorry" / "Oops" — too apologetic, sounds patronizing
- All-caps shouting
- Emoji in critical paths (OK in marketing / onboarding, never in
  errors or destructive copy)
- Saying "user" — say "you" or the person's role (director, teacher)
