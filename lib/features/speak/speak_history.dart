import 'dart:convert';

import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One saved Speak piece — the text, the voice it was read in, and the timed
/// script (audio URL + word timings). Because the script is stored, replaying
/// a history entry is INSTANT and calls NOTHING: the audio URL points at the
/// already-cached file in Storage, and the word timings come straight from
/// here — no Edge Function, no ElevenLabs, ever again for this piece.
@immutable
class SpeakHistoryEntry {
  const SpeakHistoryEntry({
    required this.text,
    required this.voiceId,
    required this.script,
    required this.createdAtMs,
  });

  factory SpeakHistoryEntry.fromJson(Map<String, dynamic> j) =>
      SpeakHistoryEntry(
        text: j['text'] as String,
        voiceId: j['voice'] as String,
        script: SpokenScript.fromJson(
          (j['script'] as Map).cast<String, dynamic>(),
        ),
        createdAtMs: j['at'] as int? ?? 0,
      );

  final String text;
  final String voiceId;
  final SpokenScript script;

  /// Epoch millis — passed in by the caller (the model can't read the clock).
  final int createdAtMs;

  Map<String, dynamic> toJson() => {
    'text': text,
    'voice': voiceId,
    'script': script.toJson(),
    'at': createdAtMs,
  };
}

/// Local, on-device store of recent Speak pieces (SharedPreferences-backed).
/// Not synced — it's personal scratch history, and the audio it points at is
/// the shared server cache. Newest first, deduped by (text, voice), capped.
class SpeakHistory {
  static const String _key = 'speak_history_v1';
  static const int _max = 20;

  Future<List<SpeakHistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final e in list)
          SpeakHistoryEntry.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } on Object catch (e) {
      if (kDebugMode) debugPrint('[speak] history parse failed: $e');
      return const [];
    }
  }

  /// Prepend [entry] (newest first), drop any prior entry with the same text +
  /// voice, cap to [_max], persist, and return the new list.
  Future<List<SpeakHistoryEntry>> add(SpeakHistoryEntry entry) async {
    final current = await load();
    final next = <SpeakHistoryEntry>[
      entry,
      ...current.where(
        (e) => !(e.text == entry.text && e.voiceId == entry.voiceId),
      ),
    ];
    final capped = next.take(_max).toList();
    await _persist(capped);
    return capped;
  }

  Future<List<SpeakHistoryEntry>> clear() async {
    await _persist(const []);
    return const [];
  }

  Future<void> _persist(List<SpeakHistoryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode([for (final e in entries) e.toJson()]),
    );
  }
}
