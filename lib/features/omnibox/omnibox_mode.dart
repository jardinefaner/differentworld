import 'package:differentworld/features/omnibox/omnibox_entries.dart';

/// What the composer's input is currently doing. The bar's leading
/// icon + hint text + submit behavior pivot on this.
///
///   - [search] — typing fuzzy-matches the catalog; Enter opens the
///     top-ranked result. This is the "Spotlight / Cmd+K" feel.
///   - [capture] — the user's typed something that doesn't match
///     anything in the catalog and reads as a note; Enter saves it
///     via `captureActionsProvider.create`. This is the "save a
///     thought" feel.
///
/// Future modes (slash commands, ask-AI, quick-block) plug in here
/// without restructuring the bar or panel — they'd just be additional
/// enum values with their own detection rules in [detectMode].
enum OmniboxMode { search, capture, slash }

/// Sniff the user's intent from the current query string and catalog.
///
/// Decision tree (cheapest checks first):
///
///   1. Empty / very short query → [OmniboxMode.search]. Don't switch
///      modes before the user has committed enough text to mean
///      something.
///   2. Catalog has a strong match (any entry whose label contains
///      the query, score ≥ 200) → [OmniboxMode.search]. Catalog
///      wins; we don't want to steal the user's keystrokes away
///      from a real match.
///   3. Query has multiple words OR is long-ish (≥10 chars) AND no
///      strong catalog match → [OmniboxMode.capture]. Reads as a
///      free-form note; Enter saves it.
///   4. Otherwise → [OmniboxMode.search]. Default to non-destructive.
///
/// Detection runs on every keystroke. The cost is one pass through
/// the catalog with each entry's pre-existing `score()` — cheap.
OmniboxMode detectMode({
  required String query,
  required List<OmniboxEntry> catalog,
}) {
  final raw = query.trimLeft();
  // Slash mode wins as soon as the user types `/` — the leading
  // slash is the explicit "I want to invoke a command" signal.
  // Match on the trimmed-LEFT string so we don't break on a leading
  // space, but a trailing word still counts.
  if (raw.startsWith('/')) return OmniboxMode.slash;
  final q = query.trim().toLowerCase();
  if (q.isEmpty || q.length < 3) return OmniboxMode.search;

  var bestScore = 0;
  for (final e in catalog) {
    final s = e.score(q);
    if (s > bestScore) bestScore = s;
  }
  // 200 = exact-match-keyword threshold in OmniboxEntry.score; any
  // entry that contains the query as a substring scores ≥ 200. So if
  // bestScore < 200, nothing in the catalog actually contains the
  // user's text — that's the signal to consider capture mode.
  if (bestScore >= 200) return OmniboxMode.search;

  final hasSpace = q.contains(' ');
  if ((hasSpace && q.length >= 5) || q.length >= 10) {
    return OmniboxMode.capture;
  }
  return OmniboxMode.search;
}
