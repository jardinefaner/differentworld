import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_generators.dart';
import 'package:flutter/foundation.dart';

/// Cross-open "recently served" memory so each time you open a game it serves
/// UNSEEN content first. v1 is in-memory + process-wide (resets on app
/// restart) — the combinatorial generators already make cross-restart repeats
/// negligible for generated kinds; persisting this (SharedPreferences) for the
/// authored kinds is a clean follow-up.
class ContentMemory {
  ContentMemory({this.cap = 300});

  final int cap;
  final Map<String, List<String>> _recent = {};

  /// Fingerprints recently served for [kind] (the de-prioritise set).
  Set<String> recent(String kind) => {...?_recent[kind]};

  void record(String kind, String fingerprint) {
    (_recent[kind] ??= <String>[])
      ..remove(fingerprint) // move-to-front: most-recent last
      ..add(fingerprint);
    final list = _recent[kind]!;
    if (list.length > cap) list.removeRange(0, list.length - cap);
  }

  @visibleForTesting
  void clear() => _recent.clear();
}

/// Process-wide memory the engine uses by default.
final ContentMemory contentMemory = ContentMemory();

/// The content source games actually use: the curated/crowd floor PLUS the
/// combinatorial [contentGenerators] PLUS a recently-served memory so each
/// open is fresh. A drop-in for [LocalContentBank] (same [ContentSource]
/// interface) — games never change.
///
/// - A kind WITH a generator (story, this-or-that, …) is produced
///   procedurally, skipping anything recently served — effectively infinite,
///   always new.
/// - A kind WITHOUT one (riddles, fact/fib, charades, rhyme — authored, not
///   combinable) serves the curated/crowd pool, preferring items not served
///   recently before recycling.
class ContentEngine implements ContentSource {
  ContentEngine(
    List<ContentItem> items, {
    Map<String, ContentGenerator>? generators,
    ContentMemory? memory,
    Random? random,
  })  : _generators = generators ?? contentGenerators,
        _memory = memory ?? contentMemory,
        _rng = random ?? Random() {
    for (final item in items) {
      if (_loaded.add('${item.kind}/${item.fingerprint}')) {
        (_byKind[item.kind] ??= <ContentItem>[]).add(item);
      }
    }
  }

  final Map<String, ContentGenerator> _generators;
  final ContentMemory _memory;
  final Random _rng;
  final Map<String, List<ContentItem>> _byKind = {};
  final Set<String> _loaded = {};
  final Set<String> _served = {};

  String _key(ContentItem i) => '${i.kind}/${i.fingerprint}';

  @override
  List<ContentItem> take(String kind, int n) {
    final out = <ContentItem>[];
    final gen = _generators[kind];
    if (gen != null) {
      final items = gen.generate(
        n,
        _rng,
        exclude: {..._served, ..._memory.recent(kind)},
      );
      for (final it in items) {
        _served.add(_key(it));
        _memory.record(kind, it.fingerprint);
        out.add(it);
      }
      return out;
    }
    // Authored pool: unseen this session, preferring not-recently-served.
    final pool = _byKind[kind] ?? const <ContentItem>[];
    final recent = _memory.recent(kind);
    final fresh = <ContentItem>[];
    final stale = <ContentItem>[];
    for (final it in pool) {
      if (_served.contains(_key(it))) continue;
      (recent.contains(it.fingerprint) ? stale : fresh).add(it);
    }
    // Randomise within each tier so take(N) is varied; fresh still serves
    // before recycling stale.
    fresh.shuffle(_rng);
    stale.shuffle(_rng);
    for (final it in [...fresh, ...stale]) {
      if (out.length >= n) break;
      _served.add(_key(it));
      _memory.record(kind, it.fingerprint);
      out.add(it);
    }
    return out;
  }

  @override
  ContentItem? next(String kind) {
    final items = take(kind, 1);
    return items.isEmpty ? null : items.first;
  }

  @override
  int remaining(String kind) {
    final gen = _generators[kind];
    if (gen != null) {
      final servedOfKind = _served.where((s) => s.startsWith('$kind/')).length;
      return (gen.space - servedOfKind).clamp(0, gen.space);
    }
    return (_byKind[kind] ?? const <ContentItem>[])
        .where((i) => !_served.contains(_key(i)))
        .length;
  }
}
