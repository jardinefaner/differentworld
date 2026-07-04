import 'dart:async';

import 'package:differentworld/features/voice/deepgram_voice_service.dart';
import 'package:flutter/material.dart';

/// The shared Deepgram dictation state machine — toggle a session, stream
/// transcript updates into a text field while preserving whatever the user
/// had already typed, surface errors via SnackBar, and tear the
/// subscription down on stop / error / idle.
///
/// One copy of the pattern previously cloned across the capture screen,
/// the observation form, the survey text answer, and the omnibox search
/// page. The host State supplies the voice controller + target field and
/// keeps ownership of their lifecycles (a form-local controller is
/// disposed by the host; the omnibox's shared singleton is merely
/// cancelled) — call [cancelDictationSub] from `dispose()`.
mixin DictationMixin<T extends StatefulWidget> on State<T> {
  StreamSubscription<VoiceUpdate>? _dictationSub;
  bool _dictationActive = false;
  String _dictationPrefix = '';

  /// Whether a dictation session is live — drives the mic/stop affordance.
  bool get voiceActive => _dictationActive;

  /// The voice controller the session runs on. Resolved lazily by hosts
  /// that use the shared singleton (it's only read inside [toggleDictation]).
  @protected
  DeepgramVoiceController get dictationVoice;

  /// The field the transcript lands in. Writing `.text` fires the host's
  /// controller listeners exactly like typing, so autosave rides for free.
  @protected
  TextEditingController get dictationField;

  /// Hook: fires after the session is marked active, before subscribing —
  /// the omnibox re-requests focus + forces the IME up here.
  @protected
  void onDictationStarted() {}

  /// Hook: fires after each transcript chunk is written into the field —
  /// the survey answer routes its debounced autosave through this.
  @protected
  void onDictationText(String combined) {}

  /// Toggle the session: tap once → start recording + streaming; tap
  /// again → stop and keep the transcript. Snapshot whatever the user
  /// typed before the session starts and append the live transcript.
  @protected
  void toggleDictation() {
    if (_dictationActive) {
      unawaited(dictationVoice.stop());
      return;
    }
    _dictationPrefix = dictationField.text;
    setState(() => _dictationActive = true);
    onDictationStarted();
    _dictationSub = dictationVoice.updates.listen(_onDictationUpdate);
    try {
      unawaited(dictationVoice.start());
    } on Object catch (_) {
      // A synchronous start() failure would otherwise strand the mic on
      // "recording" with no update ever arriving to reset it.
      cancelDictationSub();
      setState(() => _dictationActive = false);
    }
  }

  /// Cancel the live subscription (no-op when idle). Call from `dispose()`
  /// BEFORE disposing the field so a late transcript can't land in it.
  @protected
  void cancelDictationSub() {
    unawaited(_dictationSub?.cancel());
    _dictationSub = null;
  }

  void _onDictationUpdate(VoiceUpdate update) {
    if (!mounted) return;
    if (update.state == VoiceState.error) {
      cancelDictationSub();
      final msg = update.errorMessage ?? 'Voice dictation failed.';
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _dictationActive = false);
      return;
    }
    final transcript = update.transcript.trim();
    final glue = (_dictationPrefix.isEmpty || transcript.isEmpty) ? '' : ' ';
    final combined = '$_dictationPrefix$glue$transcript';
    dictationField
      ..text = combined
      ..selection = TextSelection.collapsed(offset: combined.length);
    onDictationText(combined);
    if (update.state == VoiceState.idle) {
      _dictationActive = false;
      cancelDictationSub();
      setState(() {});
    }
  }
}
