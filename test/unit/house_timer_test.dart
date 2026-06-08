import 'package:differentworld/features/action_words/house_timer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The program-policy timer concern: the director's "house" presets, stored as
/// JSON on the Space caps. Pure decode/encode/sanitize — the resilient floor
/// that keeps a corrupt or empty cap from ever leaving the timer with no
/// quick durations.
void main() {
  group('decodeTimerPresets', () {
    test('null / empty falls back to the default', () {
      expect(decodeTimerPresets(null), kDefaultTimerPresetMinutes);
      expect(decodeTimerPresets(''), kDefaultTimerPresetMinutes);
    });

    test('a valid list decodes, dedupes, and sorts', () {
      expect(decodeTimerPresets('[10, 2, 5, 2]'), [2, 5, 10]);
    });

    test('out-of-range minutes are dropped', () {
      expect(decodeTimerPresets('[0, 1, 61, 30]'), [1, 30]);
    });

    test('a list with nothing valid falls back to the default', () {
      expect(decodeTimerPresets('[0, 61, 999]'), kDefaultTimerPresetMinutes);
    });

    test('corrupt or non-list JSON falls back to the default', () {
      expect(decodeTimerPresets('not json'), kDefaultTimerPresetMinutes);
      expect(decodeTimerPresets('{"a":1}'), kDefaultTimerPresetMinutes);
    });

    test('non-integer numbers truncate to whole minutes', () {
      expect(decodeTimerPresets('[5.9, 2.1]'), [2, 5]);
    });
  });

  group('encode + sanitize', () {
    test('encode sanitizes: dedupe, sort, clamp', () {
      expect(encodeTimerPresets([10, 2, 2, 61, 0, 5]), '[2,5,10]');
    });

    test('round-trips through decode', () {
      expect(decodeTimerPresets(encodeTimerPresets([7, 3, 3, 12])), [3, 7, 12]);
    });

    test('sanitize keeps empty empty (the caller decides fallback)', () {
      expect(sanitizeTimerPresets(const []), isEmpty);
      expect(sanitizeTimerPresets(const [0, 61]), isEmpty);
    });
  });
}
