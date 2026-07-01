import 'package:differentworld/features/schedule/schedule_providers.dart'
    show BlockKind;
import 'package:flutter/foundation.dart';

/// "Omnibox composes" — the middle-UI move where a plain-language phrase typed
/// into the composer (which didn't match the catalog, so it's in CAPTURE mode)
/// is recognized as an INTENT to schedule something, and offered as a *drafted
/// block* you confirm in the editor — not just a note (docs/VISION.md: "intent
/// in, structure out; you confirm the structure, never a chat reply").
///
/// Rules-based + pure: no LLM, no network. Deterministic parse of kind + when +
/// title. Returns null when the text doesn't read like a scheduling intent, so
/// a genuine note-to-self ("remember to call Devon's mom") stays a capture. The
/// draft card is ADDITIVE — the "save as a note" fallback never goes away — so a
/// false positive costs the user nothing but a glance.
@immutable
class ComposeIntent {
  const ComposeIntent({
    required this.kind,
    required this.kindLabel,
    required this.emoji,
    required this.title,
    required this.start,
    required this.dayWasExplicit,
    required this.timeWasExplicit,
  });

  /// A [BlockKind] constant — the drafted block's kind.
  final String kind;

  /// Human label for the kind chip ("Field trip", "Break", "Closed",
  /// "Activity").
  final String kindLabel;

  /// A small emoji cue for the kind / activity.
  final String emoji;

  /// The cleaned phrase that becomes the block's note (the kind words + when
  /// tokens stripped out). Falls back to [kindLabel] when nothing's left.
  final String title;

  /// The resolved start — day + time.
  final DateTime start;

  /// Whether the user named a day (vs. defaulted to today).
  final bool dayWasExplicit;

  /// Whether the user named a time (vs. defaulted to a sensible afternoon).
  final bool timeWasExplicit;
}

/// Words that, at the START of the phrase, mark it as a note-to-self rather than
/// a schedule intent — so "remember art show friday" stays a capture.
const Set<String> _noteStarters = {
  'remember', 'call', 'email', 'text', 'ask', 'tell', 'remind', 'note',
  'todo', 'buy', 'send', 'check', 'follow', 'dont', "don't", 'forgot',
};

const Map<String, int> _weekdays = {
  'monday': 1, 'mon': 1,
  'tuesday': 2, 'tue': 2, 'tues': 2,
  'wednesday': 3, 'wed': 3, 'weds': 3,
  'thursday': 4, 'thu': 4, 'thur': 4, 'thurs': 4,
  'friday': 5, 'fri': 5,
  'saturday': 6, 'sat': 6,
  'sunday': 7, 'sun': 7,
};

/// Kind trigger words to STRIP from the title (they name the structure, not the
/// subject). On-site activity nouns and break nouns are deliberately NOT here —
/// "art" / "snack" ARE the title.
const Set<String> _kindDropWords = {
  'field', 'trip', 'fieldtrip', 'excursion', 'outing', 'visit',
  'closed', 'holiday', 'program', 'offsite', 'off-site',
};

/// Generic filler stripped from the title.
const Set<String> _fillers = {
  'to', 'the', 'a', 'an', 'on', 'at', 'for', 'block', 'time', 'of', 'this',
  'next', 'let', 'lets', "let's", 'do', 'have', 'our', 'we', 'will', 'go',
  'going', 'and', 'my', 'their', 'some', 'please', 'pm', 'am', 'no', 'school',
};

/// Relative-time words that resolve to a clock time AND drop from the title.
/// "lunch"/"after" only ever appear here as part of a time phrase ("after
/// lunch") — neither triggers a kind — so dropping them is safe.
const Set<String> _relTimeWords = {
  'morning', 'afternoon', 'evening', 'tonight', 'noon', 'midday',
  'after', 'lunch',
};

/// A light emoji per on-site activity noun; falls back to a generic sparkle.
const Map<String, String> _activityEmoji = {
  'art': '🎨', 'craft': '🎨', 'paint': '🎨', 'draw': '🎨', 'drawing': '🎨',
  'read': '📖', 'reading': '📖', 'story': '📖', 'stories': '📖', 'book': '📖',
  'music': '🎵', 'sing': '🎵', 'song': '🎵', 'dance': '💃',
  'science': '🔬', 'stem': '🔬', 'experiment': '🔬',
  'game': '🎲', 'games': '🎲', 'play': '🎲', 'lego': '🧱', 'build': '🧱',
  'outdoor': '🌳', 'outside': '🌳', 'nature': '🌳', 'garden': '🌱',
  'gym': '⚽', 'sports': '⚽', 'sport': '⚽', 'soccer': '⚽',
  'movie': '🎬', 'film': '🎬', 'cooking': '🍳', 'bake': '🍳', 'baking': '🍳',
  'math': '🔢', 'writing': '✏️', 'yoga': '🧘', 'circle': '⭕',
};

/// On-site activity nouns — presence of one is a schedulable signal.
const Set<String> _activityNouns = {
  'art', 'craft', 'crafts', 'paint', 'painting', 'draw', 'drawing', 'read',
  'reading', 'story', 'stories', 'storytime', 'book', 'music', 'sing',
  'singing', 'song', 'dance', 'dancing', 'science', 'stem', 'experiment',
  'game', 'games', 'play', 'playtime', 'lego', 'legos', 'build', 'building',
  'blocks', 'outdoor', 'outside', 'nature', 'garden', 'gardening', 'gym',
  'sports', 'sport', 'soccer', 'movie', 'film', 'cooking', 'cook', 'bake',
  'baking', 'math', 'writing', 'yoga', 'circle', 'workshop', 'project',
  'activity', 'session', 'centers', 'stations',
};

/// Parse a free-text composer phrase into a schedule intent, or null.
///
/// [now] is injected (not `DateTime.now()`) so the function stays pure and
/// testable — callers pass the wall clock.
ComposeIntent? parseComposeIntent(String raw, {required DateTime now}) {
  final text = raw.trim();
  if (text.length < 3) return null;
  // The composer is a sentence box, not a document editor. A pasted paragraph
  // has nothing to schedule — cap it so build() never runs the regex battery
  // over thousands of tokens.
  if (text.length > 200) return null;
  final lower = text.toLowerCase();

  final rawTokens = text
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp('[^A-Za-z0-9:-]'), ''))
      .where((w) => w.isNotEmpty)
      .toList();
  if (rawTokens.isEmpty) return null;
  final lowerTokens = rawTokens.map((w) => w.toLowerCase()).toList();

  // Note-to-self opener → leave it a capture.
  if (_noteStarters.contains(lowerTokens.first)) return null;

  // ── Kind ──────────────────────────────────────────────────────────────────
  final String kind;
  final String kindLabel;
  var emoji = '✨';
  var strong = false; // strong kinds can fire without a when-token

  bool has(String phrase) => lower.contains(phrase);

  if (has('closed') ||
      has('no school') ||
      has('no program') ||
      has('day off') ||
      has('holiday')) {
    kind = BlockKind.closed;
    kindLabel = 'Closed';
    emoji = '🚫';
    strong = true;
  } else if (has('field trip') ||
      has('fieldtrip') ||
      has('excursion') ||
      has('outing') ||
      has('trip to') ||
      has('visit to')) {
    kind = BlockKind.fieldTrip;
    kindLabel = 'Field trip';
    emoji = '🚌';
    strong = true;
  } else if (RegExp(r'\btrip\b').hasMatch(lower)) {
    // A bare "trip" ("zoo trip Friday") is a field trip too, but weak: it
    // needs a when-token to fire, so "what a trip" / "gear for trip" stay
    // notes rather than hijacking the composer.
    kind = BlockKind.fieldTrip;
    kindLabel = 'Field trip';
    emoji = '🚌';
  } else if (RegExp(r'\bbreak\b').hasMatch(lower) ||
      has('snack') ||
      has('recess') ||
      has('downtime') ||
      has('quiet time') ||
      has('rest time')) {
    kind = BlockKind.breakBlock;
    kindLabel = 'Break';
    emoji = '☕';
  } else if (lowerTokens.any(_activityNouns.contains)) {
    kind = BlockKind.onSite;
    kindLabel = 'Activity';
    final noun = lowerTokens.firstWhere(_activityNouns.contains);
    emoji = _activityEmoji[noun] ?? '✨';
  } else {
    // No kind signal at all — not a schedule intent.
    return null;
  }

  // ── When: day ───────────────────────────────────────────────────────────
  final today = DateTime(now.year, now.month, now.day);
  var day = today;
  var dayWasExplicit = false;
  var fromWeekday = false;
  if (RegExp(r'\btomorrow\b').hasMatch(lower)) {
    day = today.add(const Duration(days: 1));
    dayWasExplicit = true;
  } else if (RegExp(r'\btoday\b').hasMatch(lower)) {
    dayWasExplicit = true;
  } else {
    for (final t in lowerTokens) {
      final wd = _weekdays[t];
      if (wd != null) {
        var delta = (wd - today.weekday) % 7;
        if (delta < 0) delta += 7; // next occurrence; today if it matches
        day = today.add(Duration(days: delta));
        dayWasExplicit = true;
        fromWeekday = true;
        break;
      }
    }
  }

  // ── When: time ──────────────────────────────────────────────────────────
  final time = _parseTime(lower);
  final timeWasExplicit = time != null;
  var start = time != null
      ? DateTime(day.year, day.month, day.day, time.hour, time.minute)
      : _defaultStart(day, today, now);
  // A named weekday with an explicit time that already passed today means the
  // NEXT occurrence — roll a week forward so a draft never lands in the past.
  // (The default-time path already guards "today".)
  if (fromWeekday && timeWasExplicit && start.isBefore(now)) {
    start = start.add(const Duration(days: 7));
  }

  // Firing rule: a strong kind (field trip / closed) stands on its own; a
  // softer kind (activity / break) needs a when-token so we don't hijack a
  // bare noun like "snack" that's really a note.
  final hasWhen = dayWasExplicit || timeWasExplicit;
  if (!strong && !hasWhen) return null;

  // ── Title: strip kind + when + filler, keep the subject ──────────────────
  final kept = <String>[];
  for (var i = 0; i < rawTokens.length; i++) {
    final lw = lowerTokens[i];
    if (_kindDropWords.contains(lw)) continue;
    if (_fillers.contains(lw)) continue;
    if (_relTimeWords.contains(lw)) continue;
    if (_weekdays.containsKey(lw)) continue;
    if (lw == 'today' || lw == 'tomorrow') continue;
    if (RegExp(r'^\d{1,2}(:\d{2})?$').hasMatch(lw)) continue;
    if (RegExp(r'^\d{1,2}(:\d{2})?(am|pm)$').hasMatch(lw)) continue;
    kept.add(rawTokens[i]);
  }
  var title = kept.join(' ').trim();
  if (title.isEmpty) {
    title = kindLabel;
  } else {
    title = title[0].toUpperCase() + title.substring(1);
  }

  return ComposeIntent(
    kind: kind,
    kindLabel: kindLabel,
    emoji: emoji,
    title: title,
    start: start,
    dayWasExplicit: dayWasExplicit,
    timeWasExplicit: timeWasExplicit,
  );
}

/// Pull a clock time from the phrase. Tries, in order: an "at N[:MM]" phrase, a
/// standalone "N[:MM]am/pm", a bare "N:MM", then relative words. Returns null if
/// none — deliberately NOT treating a bare number ("3 kids") as a time.
({int hour, int minute})? _parseTime(String lower) {
  // "at 2", "at 2:30", "at 2pm", "at 2:30 pm"
  final at = RegExp(r'\bat\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b').firstMatch(lower);
  if (at != null) {
    return _resolveTime(at.group(1)!, at.group(2), at.group(3));
  }
  // "2pm", "2:30pm", "3 pm"
  final ap = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b').firstMatch(lower);
  if (ap != null) {
    return _resolveTime(ap.group(1)!, ap.group(2), ap.group(3));
  }
  // "3:30" (a colon is a strong time signal on its own)
  final colon = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(lower);
  if (colon != null) {
    return _resolveTime(colon.group(1)!, colon.group(2), null);
  }
  // Relative words → typical afterschool clock times.
  if (RegExp(r'\bnoon\b|\bmidday\b').hasMatch(lower)) return (hour: 12, minute: 0);
  if (RegExp(r'\bmorning\b').hasMatch(lower)) return (hour: 9, minute: 0);
  if (RegExp(r'after lunch|\bafternoon\b').hasMatch(lower)) {
    return (hour: 13, minute: 0);
  }
  if (RegExp(r'\bevening\b|\btonight\b').hasMatch(lower)) {
    return (hour: 17, minute: 0);
  }
  return null;
}

/// Sensible afterschool default when no time was named: 3:00 PM. If that's
/// already past on *today*, use the next half-hour boundary (or the current
/// time when already on the hour) so the draft doesn't land in the past.
DateTime _defaultStart(DateTime day, DateTime today, DateTime now) {
  final threePm = DateTime(day.year, day.month, day.day, 15);
  if (day != today || threePm.isAfter(now)) return threePm;
  final add = now.minute == 0
      ? 0
      : (now.minute <= 30 ? 30 - now.minute : 60 - now.minute);
  return DateTime(now.year, now.month, now.day, now.hour, now.minute)
      .add(Duration(minutes: add));
}

({int hour, int minute})? _resolveTime(String h, String? m, String? ampm) {
  var hour = int.tryParse(h);
  if (hour == null || hour > 23) return null;
  final minute = (m == null ? 0 : int.tryParse(m) ?? 0).clamp(0, 59);
  if (ampm != null) {
    final pm = ampm.startsWith('p');
    if (pm && hour < 12) hour += 12;
    if (!pm && hour == 12) hour = 0;
  } else {
    // No am/pm: afterschool bias — 1..7 read as PM; 8..11 stay AM; 12 = noon.
    if (hour >= 1 && hour <= 7) hour += 12;
  }
  if (hour > 23) return null;
  return (hour: hour, minute: minute);
}
