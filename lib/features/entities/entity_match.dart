import 'package:differentworld/features/entities/entity_ref.dart';

/// One matchable term in the on-device entity index: the text to look for and
/// the [EntityRef] it resolves to. [properNounOnly] forces the occurrence in
/// the prose to start with an uppercase letter — used for person names so a
/// child called "Will" doesn't light up every "will" in a sentence.
class EntityMatchTerm {
  const EntityMatchTerm({
    required this.text,
    required this.ref,
    this.properNounOnly = false,
  });

  final String text;
  final EntityRef ref;
  final bool properNounOnly;
}

/// A resolved hit: the `[start, end)` span in the original text and its ref.
class EntitySpanMatch {
  const EntitySpanMatch({
    required this.start,
    required this.end,
    required this.ref,
  });

  final int start;
  final int end;
  final EntityRef ref;

  int get length => end - start;
}

bool _isWordChar(String ch) {
  if (ch.isEmpty) return false;
  final c = ch.codeUnitAt(0);
  return (c >= 65 && c <= 90) || // A-Z
      (c >= 97 && c <= 122) || // a-z
      (c >= 48 && c <= 57) || // 0-9
      c == 0x2019 || // ’ (curly apostrophe, in names)
      c == 0x27; // ' (straight apostrophe)
}

/// Find the entity references named in [text], on-device. PURE — no Flutter, no
/// network — so it's unit-testable and so children's names NEVER leave the
/// device (the PII contract). The autotagging brain:
///
/// - whole-word matches only (word boundaries on both sides),
/// - [EntityMatchTerm.properNounOnly] terms must start uppercase in the prose,
/// - longest match wins on overlap ("Free play" beats "play"), earliest breaks
///   ties — so the returned list is non-overlapping and sorted by `start`,
/// - [exclude] drops refs the caller must not link — the family-scope guard
///   passes OTHER children's refs here so an exported keepsake can't re-leak the
///   identity `scrubOtherNames` strips.
List<EntitySpanMatch> findEntityMatches(
  String text,
  List<EntityMatchTerm> terms, {
  Set<EntityRef> exclude = const {},
}) {
  if (text.isEmpty || terms.isEmpty) return const [];
  final lower = text.toLowerCase();
  final hits = <EntitySpanMatch>[];

  for (final term in terms) {
    if (term.text.length < 2 || exclude.contains(term.ref)) continue;
    final needle = term.text.toLowerCase();
    var from = 0;
    while (true) {
      final i = lower.indexOf(needle, from);
      if (i < 0) break;
      final end = i + needle.length;
      from = i + 1;
      final beforeOk = i == 0 || !_isWordChar(text[i - 1]);
      final afterOk = end >= text.length || !_isWordChar(text[end]);
      if (!beforeOk || !afterOk) continue;
      if (term.properNounOnly && text[i].toUpperCase() != text[i]) continue;
      hits.add(EntitySpanMatch(start: i, end: end, ref: term.ref));
    }
  }
  if (hits.isEmpty) return const [];

  // Resolve overlaps: longest first, earliest as the tiebreak; greedily keep
  // a hit only if its span is still free.
  hits.sort((a, b) {
    final byLen = b.length.compareTo(a.length);
    return byLen != 0 ? byLen : a.start.compareTo(b.start);
  });
  final taken = List<bool>.filled(text.length, false);
  final chosen = <EntitySpanMatch>[];
  for (final h in hits) {
    var free = true;
    for (var k = h.start; k < h.end; k++) {
      if (taken[k]) {
        free = false;
        break;
      }
    }
    if (!free) continue;
    for (var k = h.start; k < h.end; k++) {
      taken[k] = true;
    }
    chosen.add(h);
  }
  chosen.sort((a, b) => a.start.compareTo(b.start));
  return chosen;
}
