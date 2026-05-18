---
name: commit-message-style
description: Commit messages — subject line + body explaining the "why", not the "what". Triggered when crafting a git commit.
---

# Commit message style

Match the existing voice — single short subject, body that explains
*why*, never a literal restatement of the diff.

## Format

```
Subject: short imperative, < 70 chars, no period

Optional 1-3 paragraph body explaining the why, the trade-offs, the
caveats. Wrap at ~72 chars.

- Bullet points for multiple changes if it helps
- Specifics over generics

Known gap (deferred): one-liner if applicable.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

## Subject rules

- Imperative verb-noun: "Add", "Fix", "Wire", "Rename"
- Not past tense ("Added"), not gerund ("Adding")
- < 70 chars
- No trailing period
- Lowercase first letter after a colon: `Photos: pick + compress + upload`

## Body rules

- Skip the body for trivial changes (typo fixes, dep bumps)
- For non-trivial work, explain:
  - What problem this solves
  - Why this approach over alternatives
  - Any trade-offs or known gaps
- Bullet specific files only when it adds clarity
- "Known gap (deferred)" callout if shipping with a documented TODO

## What never goes in commit messages

- The literal diff ("Changed line 42 from X to Y" — `git show` already
  knows)
- Effusive language ("This commit revolutionizes the way…")
- Apologies ("Sorry for the breaking change")
- Internal jokes / non-actionable banter

## Examples

Past commits to mirror:

- `Capabilities editor: Group, Space, and Member surfaces` — composite
  feature with bulleted file list, then `Co-Authored-By`
- `Navigation: push instead of go for drill-ins; snappier transitions` —
  subject is the change + the user-facing effect
- `No nav bars: edge-to-edge content + floating glass chrome` — names
  the user's preference + the implementation

## Co-Authored-By

Always include for AI-written commits:

```
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

## Pass via HEREDOC

For multi-line messages, always use heredoc to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
Subject line

Body.

Co-Authored-By: ...
EOF
)"
```
