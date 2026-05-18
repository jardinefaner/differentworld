---
name: screenshot-pixel
description: Capture a screenshot from the connected Pixel for the user to see / for debugging UI state.
---

# /screenshot-pixel — capture a frame

```bash
adb -s adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp \
  exec-out screencap -p > /tmp/dw-screen.png
```

Then read the image via the `Read` tool with `file_path: /tmp/dw-screen.png`
— Claude can interpret PNG bytes directly.

## When useful

- The user describes a visual issue but doesn't attach a screenshot
- You want to verify your conversion of a screen worked
- Comparing before/after a redesign
- Debugging gesture / overlay issues

## Don't

- Don't capture screens with student PII visible and then dump the bytes
  to logs — PII contract per CLAUDE.md
- Don't auto-capture in tight loops; one screenshot at a time
