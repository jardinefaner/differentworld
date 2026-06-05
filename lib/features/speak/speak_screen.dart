import 'dart:async';

import 'package:differentworld/features/speak/speak_history.dart';
import 'package:differentworld/features/speak/speak_immersive.dart';
import 'package:differentworld/features/speak/speak_input_controls.dart';
import 'package:differentworld/features/speak/speak_performer.dart';
import 'package:differentworld/features/speak/speak_presentation.dart';
import 'package:differentworld/features/speak/speak_service.dart';
import 'package:differentworld/features/speak/speak_voices.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/speak` — paste any prompt / quote / block, hear it read aloud, and watch
/// it take the stage as big, elegant, editorial type: one line at a time, the
/// spoken word swelling in weight (the Speak feature; docs/FEATURE_CHECKLISTS).
/// Voice + word-timings come from the `tts-subtitles` Edge Function
/// (ElevenLabs). An enhancement — needs network + the server key; it degrades
/// to a clear "set it up" message, never blocks.
class SpeakScreen extends ConsumerStatefulWidget {
  const SpeakScreen({super.key});

  @override
  ConsumerState<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends ConsumerState<SpeakScreen> {
  final TextEditingController _controller = TextEditingController();
  final SpeakService _service = SpeakService();
  final SpeakHistory _history = SpeakHistory();
  // Cached so dispose() can reset it without touching ref.
  late final SpeakImmersive _immersive;
  SpokenScript? _script;
  List<SpokenLine> _lines = const <SpokenLine>[];
  List<SpokenWord> _words = const <SpokenWord>[];
  List<SpokenLine> _pages = const <SpokenLine>[]; // split on input line breaks
  List<SpeakHistoryEntry> _recents = const <SpeakHistoryEntry>[];
  SpeakType _type = SpeakType.serif;
  SpeakVoice _voice = speakVoices.first;
  SpeakPresentation _mode = SpeakPresentation.editorial;
  bool _loading = false;
  String? _error;

  /// Bumped on every speak + every exit. A synthesize() that resolves after
  /// its generation is stale is discarded — otherwise tapping "New text"
  /// mid-synthesis would thrust you back into a performance you just left.
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _immersive = ref.read(speakImmersiveProvider.notifier);
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    _immersive.exit(); // never leave the omnibox hidden after we leave
    _controller.dispose();
    unawaited(_service.dispose());
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final r = await _history.load();
    if (!mounted) return;
    setState(() => _recents = r);
  }

  Future<void> _saveToHistory(
    String text,
    String voiceId,
    SpokenScript script,
  ) async {
    final r = await _history.add(
      SpeakHistoryEntry(
        text: text,
        voiceId: voiceId,
        script: script,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (!mounted) return;
    setState(() => _recents = r);
  }

  /// Replay a saved piece — loads the stored script + cached audio. NO
  /// synthesize, NO Edge Function call, NO ElevenLabs.
  void _replayFromHistory(SpeakHistoryEntry e) {
    _gen++; // invalidate any in-flight synthesize
    FocusScope.of(context).unfocus();
    final voice = speakVoices.firstWhere(
      (v) => v.id == e.voiceId,
      orElse: () => _voice,
    );
    setState(() {
      _voice = voice;
      _controller.text = e.text;
      _script = e.script;
      _words = e.script.words;
      _lines = linesFromWords(e.script.words);
      _pages = pagesFromInput(e.text, e.script.words);
      _loading = false;
      _error = null;
    });
    unawaited(_playAndReport(e.script));
  }

  Future<void> _clearHistory() async {
    final r = await _history.clear();
    if (!mounted) return;
    setState(() => _recents = r);
  }

  /// Start playback and surface a load failure (offline / bad URL) — otherwise
  /// the stage would run its highlights over silence with no explanation.
  Future<void> _playAndReport(SpokenScript script) async {
    final ok = await _service.play(script);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't play the audio — you may be offline."),
        ),
      );
    }
  }

  Future<void> _speak() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    final gen = ++_gen;
    // Dismiss the keyboard before we (may) swap to the full-bleed perform
    // view — otherwise the IME can linger open behind it on Android.
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final SpokenScript script;
    try {
      script = await _service.synthesize(text: text, voiceId: _voice.id);
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'speak'),
      );
      if (!mounted || gen != _gen) return;
      setState(() {
        _loading = false;
        _error =
            'Could not voice that — the voice service may be offline or '
            'not set up yet.';
      });
      return;
    }
    // Discard a result the user already navigated away from (stale generation).
    if (!mounted || gen != _gen) return;
    setState(() {
      _script = script;
      _words = script.words;
      _lines = linesFromWords(script.words);
      _pages = pagesFromInput(text, script.words);
      _loading = false;
    });
    unawaited(_playAndReport(script));
    // Save so it can be replayed later with no re-synthesis.
    unawaited(_saveToHistory(text, _voice.id, script));
  }

  void _newText() {
    _gen++; // invalidate any in-flight synthesize so it can't pull us back in
    unawaited(_service.stop());
    setState(() {
      _script = null;
      // A stale synth that resolves later returns early without touching this,
      // so reset it here — otherwise the button stays stuck on "Voicing…".
      _loading = false;
    });
  }

  void _toggleType() => setState(() => _type = _type.other);

  Future<void> _pickMode() async {
    final picked = await showGlassSheet<SpeakPresentation>(
      context: context,
      builder: (sheetContext) => SafeArea(
        // Scrollable — ten modes overflow a short sheet otherwise.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final m in implementedSpeakModes)
                ListTile(
                  leading: Icon(m.icon),
                  title: Text(m.label),
                  trailing: m == _mode ? const Icon(Icons.check) : null,
                  selected: m == _mode,
                  onTap: () => Navigator.of(sheetContext).pop(m),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _mode = picked);
  }

  @override
  Widget build(BuildContext context) {
    final performing = _script != null;
    // Only the PERFORMANCE is immersive (omnibox hidden) — not the input
    // composer. Defer the write past this build phase (AppShell watches it).
    if (ref.read(speakImmersiveProvider) != performing) {
      unawaited(
        Future.microtask(() {
          if (!mounted) return;
          if (performing) {
            _immersive.enter();
          } else {
            _immersive.exit();
          }
        }),
      );
    }
    return EdgeScaffold(
      // Perform-mode controls live in the top chrome pill — keeps the stage
      // full-bleed and clear of the floating omnibox bar at the bottom.
      actions: performing
          ? <Widget>[
              SecondaryActionButton(
                tooltip: 'Mode: ${_mode.label} — tap to change',
                icon: _mode.icon,
                onPressed: () => unawaited(_pickMode()),
              ),
              SecondaryActionButton(
                tooltip: 'Type: ${_type.label} — tap to switch',
                icon: Icons.text_fields_rounded,
                onPressed: _toggleType,
              ),
              SecondaryActionButton(
                tooltip: 'New text',
                icon: Icons.edit_outlined,
                onPressed: _newText,
              ),
              PrimaryActionButton(
                tooltip: 'Replay',
                icon: Icons.replay,
                onPressed: () => unawaited(_service.replay()),
              ),
            ]
          : const <Widget>[],
      // Input view clears the chrome via SafeArea; the perform view is
      // intentionally full-bleed (chrome floats over the dark stage, like the
      // camera) so the type owns the whole surface.
      body: performing
          ? _perform(context)
          : SafeArea(bottom: false, child: _input(context)),
    );
  }

  Widget _input(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'Speak',
              subtitle:
                  'Paste a prompt, quote, or block — hear it read aloud '
                  'and set big, one elegant line at a time',
            ),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 8,
              // Bound the cost (and the ElevenLabs bill) on a giant paste.
              maxLength: 2000,
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type or paste anything to read aloud…',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const PrivacyNote(),
            const SizedBox(height: 16),
            VoiceSelector(
              selected: _voice,
              onChanged: (v) => setState(() => _voice = v),
            ),
            const SizedBox(height: 14),
            TypeSelector(
              selected: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 14),
            ModeSelector(
              selected: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
            const SizedBox(height: 16),
            Text(
              'A clear voice reads it aloud while each line takes the stage — '
              'the spoken word swells. Tap the stage to pause; switch the voice '
              'or type any time. (In Packed, each line you type is its own page.)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorNote(message: _error!),
              const SizedBox(height: 16),
            ],
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _loading ? null : _speak,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.graphic_eq),
                label: Text(
                  _loading ? 'Voicing…' : 'Speak it',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (_recents.isNotEmpty) ...[
              const SizedBox(height: 24),
              RecentList(
                entries: _recents,
                onTap: _replayFromHistory,
                onClear: () => unawaited(_clearHistory()),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _perform(BuildContext context) {
    // Full-bleed living stage in the voice's palette — the performer owns the
    // living background now (it pauses the drift while the audio is idle).
    return SpeakPerformer(
      service: _service,
      mode: _mode,
      lines: _lines,
      words: _words,
      pages: _pages,
      type: _type,
      palette: _voice.palette,
    );
  }
}
