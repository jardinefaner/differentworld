// The args a GameIntent carries, as documented, must be the args something
// actually reads.
//
// `GameIntent.pick` was documented as `{'choice': int|String}` for a long
// time. Every sender and every reader uses `{'cell': int}`; nothing has ever
// sent or read `choice` on a pick. That is not a cosmetic slip — a probe
// written from the doc sends a key the reducer ignores, so every tap is
// silently a no-op and the test passes while exercising NOTHING. It read as
// "Battleship never scores and never ends" until the key was checked.
// `{'by': int}` and `{'bucket': String}` were documented on `tally` and are
// read by nothing at all.
//
// So: every key named in an intent's doc comment has to be a key some reducer
// really reads, and every key a sender really sends has to be documented.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keys that are structural rather than per-intent arguments.
const _notArgs = <String>{'rulesArg'};

void main() {
  final lib = <String>[];
  setUpAll(() {
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart')) lib.add(f.readAsStringSync());
    }
  });

  /// Keys named inside the `GameIntent` enum's doc comments.
  Set<String> documented() {
    final src = File('lib/features/games/game.dart').readAsStringSync();
    final enumBody = src.substring(
      src.indexOf('enum GameIntent'),
      src.indexOf('\n}', src.indexOf('enum GameIntent')),
    );
    return {
      for (final m in RegExp(r"\{'([a-z]+)':").allMatches(enumBody))
        m.group(1)!,
    };
  }

  /// Keys a reducer really reads.
  Set<String> read() => {
    for (final src in lib)
      for (final m in RegExp(r"args\['([a-z]+)'\]").allMatches(src))
        m.group(1)!,
  };

  /// Keys a surface really sends with an intent.
  Set<String> sent() => {
    for (final src in lib)
      for (final m in RegExp(
        r'GameIntent\.[a-z]+, *\{([^}]*)\}',
      ).allMatches(src))
        for (final k in RegExp("'([a-z]+)':").allMatches(m.group(1)!))
          k.group(1)!,
  };

  test('every documented arg is one a reducer actually reads', () {
    final fiction = documented().difference(read()).difference(_notArgs);
    expect(
      fiction,
      isEmpty,
      reason:
          'the GameIntent docs name args nothing reads — anyone writing to '
          'the doc sends a key that is silently ignored: $fiction',
    );
  });

  test('every arg a surface sends is documented', () {
    final undocumented = sent().difference(documented()).difference(_notArgs);
    expect(
      undocumented,
      isEmpty,
      reason:
          'these keys ride real taps and appear in no intent doc, so the next '
          'surface has nothing to copy: $undocumented',
    );
  });

  test('senders and readers agree', () {
    // The tightest of the three: a key sent but never read is a tap that does
    // nothing; a key read but never sent is a rule nobody can reach.
    expect(
      sent().difference(read()).difference(_notArgs),
      isEmpty,
      reason: 'sent, never read',
    );
    expect(
      read().difference(sent()).difference(_notArgs),
      isEmpty,
      reason: 'read, never sent',
    );
  });
}
