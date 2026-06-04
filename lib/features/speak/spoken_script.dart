import 'package:flutter/foundation.dart';

/// One word with the time window it's spoken in — derived from ElevenLabs'
/// character-level alignment. The karaoke view highlights the word whose
/// window the audio's current position falls into.
@immutable
class SpokenWord {
  const SpokenWord({required this.text, required this.start, required this.end});

  final String text;
  final Duration start;
  final Duration end;

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

  /// Where the audio lives — a Storage URL (cached) the player loads.
  final String audioUrl;
  final List<SpokenWord> words;

  Duration get duration => words.isEmpty ? Duration.zero : words.last.end;
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

Duration _seconds(double s) =>
    Duration(microseconds: (s * Duration.microsecondsPerSecond).round());
