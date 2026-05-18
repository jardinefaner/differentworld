---
name: no-pii-in-logs
description: Don't print child names, parent contact info, observation narratives, photo URLs, or auth tokens. Triggered when adding debugPrint / print / logger calls.
---

# No PII in logs

Children's data is sensitive PII. Regulators (state licensing, COPPA in
the US) will eventually audit. Don't make their job harder.

## Forbidden in any log path

- Student names (first, last, full, initials, nickname)
- Parent / guardian names or contact info
- Observation narratives ("Toby cried at pickup today")
- Photo bytes OR signed URLs that resolve to child photos
- Supabase access / refresh tokens
- Member email addresses (yes, even staff)

## OK to log

- UUIDs (opaque — they don't leak identity to a human reader of the
  logs)
- Generic state (`'sync completed'`, `'redeem failed: NoMatchingInvite'`)
- Counts (`'12 rows in classroom roster'`)
- Provider names, route names, screen IDs

## kDebugMode gate when in doubt

```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  debugPrint('[connector] uploadData: session.user=${session.user.id}');
}
```

`kDebugMode` is `false` in profile + release builds, so the print is
stripped. This is how the Supabase connector logs the token prefix
during dev without leaking it in production.

## If you find a leak

Fix it as a small PR with the commit message tagged `[security]`. Don't
batch it with feature work — the audit trail matters.
