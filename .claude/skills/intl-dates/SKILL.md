---
name: intl-dates
description: Format dates/numbers/currency via the intl package — never hand-rolled day/month tables. Triggered when formatting a date for display.
---

# Format dates via `intl`, not hand-rolled tables

The `intl` package is pinned in pubspec. The today screen's old greeting
had ~30 lines of hand-rolled `const days = [...]; const months = [...]`
— gone, replaced by `DateFormat.yMMMMEEEEd().format(when)`.

## Common formats

```dart
import 'package:intl/intl.dart';

// "Saturday, May 17, 2026"
DateFormat.yMMMMEEEEd().format(when);

// "May 17, 2026"
DateFormat.yMMMMd().format(when);

// "2026-05-17"
DateFormat('yyyy-MM-dd').format(when);

// "3:42 PM"
DateFormat.jm().format(when);

// Relative ("today", "yesterday") — write your own; intl doesn't ship this
```

## Why

- **i18n for free** — when we eventually translate, dates auto-format
  per locale
- **Less code** — one line vs a static array per language unit
- **Correct edge cases** — first-of-month, leap years, locale ordering
  (Japanese is YYYY/MM/DD, French is DD/MM/YYYY)

## Don't

```dart
// Don't:
const months = ['January', 'February', ...];
final mon = months[when.month - 1];

// Don't:
'${when.year}-${when.month.toString().padLeft(2, '0')}-${when.day.toString().padLeft(2, '0')}'

// Do:
DateFormat('yyyy-MM-dd').format(when)
```

## ISO date strings for DB

Drift stores dates as TEXT. The convention is ISO 8601:
- Date-only: `'2026-05-17'`
- Full timestamp: `DateTime.now().toUtc().toIso8601String()` →
  `'2026-05-17T15:42:00.000Z'`

Always UTC for timestamps so sync is consistent across timezones.
