import 'package:flutter/foundation.dart';

/// One word with the time window it's spoken in — derived from ElevenLabs'
/// character-level alignment. The karaoke view highlights the word whose
/// window the audio's current position falls into.
@immutable
class SpokenWord {
  const SpokenWord({
    required this.text,
    required this.start,
    required this.end,
  });

  factory SpokenWord.fromJson(Map<String, dynamic> j) => SpokenWord(
    text: j['t'] as String,
    start: Duration(microseconds: j['s'] as int),
    end: Duration(microseconds: j['e'] as int),
  );

  final String text;
  final Duration start;
  final Duration end;

  Map<String, dynamic> toJson() => {
    't': text,
    's': start.inMicroseconds,
    'e': end.inMicroseconds,
  };

  @override
  bool operator ==(Object other) =>
      other is SpokenWord &&
      other.text == text &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(text, start, end);
}

/// A spoken script: the audio (a URL or file path the player loads) + the
/// word timings. Self-contained so the screen can play + highlight from one
/// object.
@immutable
class SpokenScript {
  const SpokenScript({required this.audioUrl, required this.words});

  factory SpokenScript.fromJson(Map<String, dynamic> j) => SpokenScript(
    audioUrl: j['url'] as String,
    words: [
      for (final w in j['words'] as List)
        SpokenWord.fromJson((w as Map).cast<String, dynamic>()),
    ],
  );

  /// Where the audio lives — a Storage URL (cached) the player loads.
  final String audioUrl;
  final List<SpokenWord> words;

  Duration get duration => words.isEmpty ? Duration.zero : words.last.end;

  Map<String, dynamic> toJson() => {
    'url': audioUrl,
    'words': words.map((w) => w.toJson()).toList(),
  };
}

/// Group ElevenLabs char-level alignment into words. The `with-timestamps`
/// endpoint returns parallel arrays: each character + its start/end seconds.
/// Whitespace is a word boundary; a word's window is its first char's start
/// to its last char's end (punctuation stays attached). Robust to ragged
/// input (mismatched lengths are truncated to the shortest).
List<SpokenWord> wordsFromAlignment({
  required List<String> characters,
  required List<double> startSeconds,
  required List<double> endSeconds,
}) {
  final n = [
    characters.length,
    startSeconds.length,
    endSeconds.length,
  ].reduce((a, b) => a < b ? a : b);

  final words = <SpokenWord>[];
  final buffer = StringBuffer();
  double? wordStart;
  var wordEnd = 0.0;

  void flush() {
    final text = buffer.toString();
    if (text.trim().isNotEmpty && wordStart != null) {
      words.add(
        SpokenWord(
          text: text,
          start: _seconds(wordStart!),
          end: _seconds(wordEnd),
        ),
      );
    }
    buffer.clear();
    wordStart = null;
  }

  for (var i = 0; i < n; i++) {
    final char = characters[i];
    if (char.trim().isEmpty) {
      flush(); // whitespace ends a word (and is itself dropped)
    } else {
      wordStart ??= startSeconds[i];
      wordEnd = endSeconds[i];
      buffer.write(char);
    }
  }
  flush();
  return words;
}

/// The index of the word being spoken at [position] — the last word whose
/// start has passed. Returns -1 before the first word (lead-in silence) so
/// the view can render the "about to start" state.
int currentWordIndex(List<SpokenWord> words, Duration position) {
  var index = -1;
  for (var i = 0; i < words.length; i++) {
    if (position >= words[i].start) {
      index = i;
    } else {
      break;
    }
  }
  return index;
}

/// One line of the editorial stage — a short phrase shown on its own, big.
/// Carries its words (so the active one can be emphasised within the line)
/// and the time window it occupies.
@immutable
class SpokenLine {
  const SpokenLine({required this.words});

  final List<SpokenWord> words;

  Duration get start => words.first.start;
  Duration get end => words.last.end;
  String get text => words.map((w) => w.text).join(' ');

  @override
  bool operator ==(Object other) =>
      other is SpokenLine &&
      other.words.length == words.length &&
      _listEquals(other.words, words);

  @override
  int get hashCode => Object.hashAll(words);
}

bool _listEquals(List<SpokenWord> a, List<SpokenWord> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Group words into short, punchy lines for the one-line-at-a-time stage.
/// The aesthetic goal: each line is a *beat* — a few words you can take in at
/// a glance, set large. Break rules, in priority order:
///   1. Always break AFTER sentence-ending punctuation (`.`, `!`, `?`).
///   2. Break AFTER clause punctuation (`,`, `;`, `:`, `—`) once the line has
///      some heft (≥ [minChars]) — avoids orphaning "Yes," on its own line.
///   3. Break BEFORE a word that would push the line past [maxChars].
/// Never emits an empty line. Pure — unit-tested.
List<SpokenLine> linesFromWords(
  List<SpokenWord> words, {
  int maxChars = 28,
  int minChars = 12,
}) {
  final lines = <SpokenLine>[];
  var current = <SpokenWord>[];
  var currentChars = 0;

  void flush() {
    if (current.isNotEmpty) {
      lines.add(SpokenLine(words: List.unmodifiable(current)));
      current = <SpokenWord>[];
      currentChars = 0;
    }
  }

  for (final word in words) {
    final wordLen = word.text.length;
    // +1 for the joining space when the line already has a word.
    final addedLen = current.isEmpty ? wordLen : wordLen + 1;

    // Rule 3: would exceed the budget → start this word on a fresh line
    // (unless the line is empty, in which case a single long word must stay).
    if (current.isNotEmpty && currentChars + addedLen > maxChars) {
      flush();
    }

    current.add(word);
    currentChars += current.length == 1 ? wordLen : addedLen;

    final trimmed = word.text.trimRight();
    final last = trimmed.isEmpty ? '' : trimmed[trimmed.length - 1];
    final sentenceEnd = last == '.' || last == '!' || last == '?';
    final clauseEnd = last == ',' || last == ';' || last == ':' || last == '—';

    if (sentenceEnd || (clauseEnd && currentChars >= minChars)) {
      flush();
    }
  }
  flush();
  return lines;
}

/// The line on screen at [position] — the last line whose start has passed, so
/// a finished line stays up through the trailing pause until the next begins.
/// Returns -1 before the first line (lead-in silence).
int lineIndexAt(List<SpokenLine> lines, Duration position) {
  var index = -1;
  for (var i = 0; i < lines.length; i++) {
    if (position >= lines[i].start) {
      index = i;
    } else {
      break;
    }
  }
  return index;
}

Duration _seconds(double s) =>
    Duration(microseconds: (s * Duration.microsecondsPerSecond).round());

/// How much a word should be visually emphasised (0..1), derived from the text
/// alone — ALL-CAPS, length, and an exclamation read as emphasis. Lets the
/// modes grow editorial hierarchy (bigger / heavier words) with no markup.
double wordEmphasis(String word) {
  final core = word.replaceAll(RegExp('[^A-Za-z0-9]'), '');
  if (core.isEmpty) return 0;
  var score = 0.0;
  // ALL-CAPS (and not a lone letter / pure digits) reads as a shout.
  if (core.length >= 2 &&
      core == core.toUpperCase() &&
      core != core.toLowerCase()) {
    score += 0.6;
  }
  // Longer words carry more weight (capped).
  score += ((core.length - 4) / 9).clamp(0.0, 0.4);
  // An exclamation is emphasis.
  if (word.contains('!')) score += 0.3;
  return score.clamp(0.0, 1.0);
}

/// Whether [word] ends a sentence — drives the "hold on the period" rhythm
/// (the closing word settles a beat more slowly).
bool endsSentence(String word) {
  final t = word.trimRight();
  if (t.isEmpty) return false;
  final last = t[t.length - 1];
  return last == '.' || last == '!' || last == '?';
}

/// Split the timed [words] into PAGES using the author's own line breaks in the
/// original [text] — every newline starts a new page (just those words). The
/// alignment gives words sequentially; we assign them to pages by the word
/// count of each non-empty input line. Robust to small count mismatches (any
/// leftover words attach to the last page). No line breaks → one page.
List<SpokenLine> pagesFromInput(String text, List<SpokenWord> words) {
  if (words.isEmpty) return const [];
  final lineCounts = <int>[];
  for (final raw in text.split('\n')) {
    final n = raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    if (n > 0) lineCounts.add(n);
  }
  if (lineCounts.length <= 1) {
    return [SpokenLine(words: List.unmodifiable(words))];
  }
  final pages = <SpokenLine>[];
  var i = 0;
  for (final count in lineCounts) {
    if (i >= words.length) break;
    final end = (i + count).clamp(0, words.length);
    pages.add(SpokenLine(words: List.unmodifiable(words.sublist(i, end))));
    i = end;
  }
  // Leftover alignment words (ragged vs the input count) → attach to the last.
  if (i < words.length && pages.isNotEmpty) {
    final last = pages.removeLast();
    pages.add(
      SpokenLine(
        words: List.unmodifiable([...last.words, ...words.sublist(i)]),
      ),
    );
  }
  return pages;
}
