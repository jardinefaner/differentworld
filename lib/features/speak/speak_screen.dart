import 'dart:async';

import 'package:differentworld/features/speak/collage_view.dart';
import 'package:differentworld/features/speak/living_background.dart';
import 'package:differentworld/features/speak/one_big_word_view.dart';
import 'package:differentworld/features/speak/speak_presentation.dart';
import 'package:differentworld/features/speak/speak_service.dart';
import 'package:differentworld/features/speak/speak_stage.dart';
import 'package:differentworld/features/speak/speak_voices.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/spotlight_view.dart';
import 'package:differentworld/features/speak/stack_view.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';

/// `/speak` — paste any prompt / quote / block, hear it read aloud, and watch
/// it take the stage as big, elegant, editorial type: one line at a time, the
/// spoken word swelling in weight (the Speak feature; docs/FEATURE_CHECKLISTS).
/// Voice + word-timings come from the `tts-subtitles` Edge Function
/// (ElevenLabs). An enhancement — needs network + the server key; it degrades
/// to a clear "set it up" message, never blocks.
class SpeakScreen extends StatefulWidget {
  const SpeakScreen({super.key});

  @override
  State<SpeakScreen> createState() => _SpeakScreenState();
}

class _SpeakScreenState extends State<SpeakScreen> {
  final TextEditingController _controller = TextEditingController();
  final SpeakService _service = SpeakService();
  SpokenScript? _script;
  List<SpokenLine> _lines = const <SpokenLine>[];
  List<SpokenWord> _words = const <SpokenWord>[];
  SpeakType _type = SpeakType.serif;
  SpeakVoice _voice = speakVoices.first;
  SpeakPresentation _mode = SpeakPresentation.stage;
  bool _loading = false;
  String? _error;

  /// Bumped on every speak + every exit. A synthesize() that resolves after
  /// its generation is stale is discarded — otherwise tapping "New text"
  /// mid-synthesis would thrust you back into a performance you just left.
  int _gen = 0;

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_service.dispose());
    super.dispose();
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
      _loading = false;
    });
    // Fire-and-forget: play() resolves only at end-of-audio and degrades
    // silently on failure (we've already shown the stage).
    unawaited(_service.play(script));
  }

  void _newText() {
    _gen++; // invalidate any in-flight synthesize so it can't pull us back in
    unawaited(_service.stop());
    setState(() => _script = null);
  }

  void _toggleType() => setState(() => _type = _type.other);

  void _cycleMode() => setState(() => _mode = nextSpeakMode(_mode));

  @override
  Widget build(BuildContext context) {
    final performing = _script != null;
    return EdgeScaffold(
      // Perform-mode controls live in the top chrome pill — keeps the stage
      // full-bleed and clear of the floating omnibox bar at the bottom.
      actions: performing
          ? <Widget>[
              SecondaryActionButton(
                tooltip: 'Mode: ${_mode.label} — tap to switch',
                icon: _mode.icon,
                onPressed: _cycleMode,
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
            const _PrivacyNote(),
            const SizedBox(height: 16),
            _VoiceSelector(
              selected: _voice,
              onChanged: (v) => setState(() => _voice = v),
            ),
            const SizedBox(height: 14),
            _TypeSelector(
              selected: _type,
              onChanged: (t) => setState(() => _type = t),
            ),
            const SizedBox(height: 14),
            _ModeSelector(
              selected: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
            const SizedBox(height: 18),
            if (_error != null) ...[
              _ErrorNote(message: _error!),
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
            const SizedBox(height: 8),
            Text(
              'A clear voice reads it aloud while each line takes the stage — '
              'the spoken word swells. Tap the stage to pause; switch the voice '
              'or type any time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perform(BuildContext context) {
    // Full-bleed living stage in the voice's palette; SpeakStage centres the
    // line, so the floating chrome (top) + omnibox bar (bottom) clear the type.
    return LivingBackground(
      palette: _voice.palette,
      child: _SpeakStageHost(
        service: _service,
        mode: _mode,
        lines: _lines,
        words: _words,
        type: _type,
        accent: _voice.palette.accent,
      ),
    );
  }
}

/// Drives [SpeakStage] from a per-frame ticker that reads the player's exact
/// position, so word/line flips land on the voice rather than up to 200ms
/// late (the position STREAM is only ~5/sec). Also owns playback CONTROL: tap
/// the stage to pause/resume; the ticker idles when not playing (no 60fps
/// spin after the voice ends); a finished performance shows a tap-to-replay
/// glyph. Rebuilds only when the active line/word changes — the implicit
/// animations interpolate smoothly between those discrete flips.
class _SpeakStageHost extends StatefulWidget {
  const _SpeakStageHost({
    required this.service,
    required this.mode,
    required this.lines,
    required this.words,
    required this.type,
    required this.accent,
  });

  final SpeakService service;
  final SpeakPresentation mode;
  final List<SpokenLine> lines;
  final List<SpokenWord> words;
  final SpeakType type;
  final Color accent;

  @override
  State<_SpeakStageHost> createState() => _SpeakStageHostState();
}

class _SpeakStageHostState extends State<_SpeakStageHost>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_onTick);
  StreamSubscription<bool>? _playSub;
  StreamSubscription<bool>? _doneSub;
  Duration _position = Duration.zero;
  int _line = -1;
  int _word = -1;
  bool _playing = false;
  bool _started = false;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _playSub = widget.service.playingStream.listen(_onPlayingChanged);
    _doneSub = widget.service.completedStream.listen(_onCompleted);
  }

  void _onPlayingChanged(bool playing) {
    if (!mounted) return;
    setState(() {
      _playing = playing;
      if (playing) {
        _started = true;
        _done = false;
      }
    });
    // Ticker runs ONLY while the voice advances — no idle 60fps spin.
    if (playing) {
      if (!_ticker.isActive) unawaited(_ticker.start());
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _onCompleted(bool completed) {
    if (!mounted || !completed) return;
    if (_ticker.isActive) _ticker.stop();
    setState(() {
      _done = true;
      _playing = false;
    });
  }

  void _onTick(Duration _) {
    final pos = widget.service.currentPosition;
    final line = lineIndexAt(widget.lines, pos);
    final word = line < 0
        ? -1
        : currentWordIndex(widget.lines[line].words, pos);
    if (line != _line || word != _word) {
      setState(() {
        _position = pos;
        _line = line;
        _word = word;
      });
    }
  }

  void _toggle() {
    if (_done) {
      unawaited(widget.service.replay());
    } else if (_playing) {
      unawaited(widget.service.pause());
    } else {
      unawaited(widget.service.resume());
    }
  }

  @override
  void dispose() {
    unawaited(_playSub?.cancel());
    unawaited(_doneSub?.cancel());
    _ticker.dispose();
    super.dispose();
  }

  /// Render the active mode. All modes read the same (lines / words /
  /// position), so switching is just a different look on the same timeline.
  /// Collage + Spotlight fall through to Stage until they're built.
  Widget _modeChild() {
    return switch (widget.mode) {
      SpeakPresentation.oneBigWord => OneBigWordView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.accent,
      ),
      SpeakPresentation.stack => StackView(
        lines: widget.lines,
        position: _position,
        type: widget.type,
        accent: widget.accent,
      ),
      SpeakPresentation.collage => CollageView(
        lines: widget.lines,
        position: _position,
        type: widget.type,
        accent: widget.accent,
      ),
      SpeakPresentation.spotlight => SpotlightView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.accent,
      ),
      SpeakPresentation.stage => SpeakStage(
        lines: widget.lines,
        position: _position,
        type: widget.type,
        accent: widget.accent,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Show the pause glyph only once playback has actually begun — never
    // during the initial load (which would flash "paused" before the voice
    // starts).
    final paused = _started && !_playing && !_done;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // One done-dim for every mode (was inside SpeakStage).
          AnimatedOpacity(
            opacity: _done ? 0.5 : 1,
            duration: const Duration(milliseconds: 400),
            child: _modeChild(),
          ),
          if (paused)
            const _StageGlyph(
              icon: Icons.play_arrow_rounded,
              semantic: 'Paused — tap to resume',
            ),
          if (_done)
            const _StageGlyph(
              icon: Icons.replay_rounded,
              semantic: 'Finished — tap to replay',
            ),
        ],
      ),
    );
  }
}

/// A large, low-opacity glyph centred on the stage — the universal
/// pause/replay affordance, kept quiet so it doesn't fight the type.
class _StageGlyph extends StatelessWidget {
  const _StageGlyph({required this.icon, required this.semantic});

  final IconData icon;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Semantics(
        label: semantic,
        child: Icon(icon, size: 92, color: Colors.white.withValues(alpha: 0.2)),
      ),
    );
  }
}

/// Pick which voice reads it. A pre-speak choice (a different voice is
/// different audio, so it re-synthesizes) — the type toggle, by contrast,
/// stays live during the performance.
class _VoiceSelector extends StatelessWidget {
  const _VoiceSelector({required this.selected, required this.onChanged});

  final SpeakVoice selected;
  final ValueChanged<SpeakVoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Voice',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in speakVoices)
              _VoiceTile(
                voice: v,
                selected: v.id == selected.id,
                onTap: () => onChanged(v),
              ),
          ],
        ),
      ],
    );
  }
}

class _VoiceTile extends StatelessWidget {
  const _VoiceTile({
    required this.voice,
    required this.selected,
    required this.onTap,
  });

  final SpeakVoice voice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final desc = voice.descriptor;
    return Semantics(
      button: true,
      selected: selected,
      label: '${voice.label} voice${desc == null ? '' : ', $desc'}',
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            // ≥48dp tap target (audit E1: ChoiceChip was ~32dp).
            constraints: const BoxConstraints(minHeight: 48, minWidth: 68),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The voice's colour identity, previewed.
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: voice.palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voice.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
                        ),
                      ),
                      if (desc != null)
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                (selected
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurfaceVariant)
                                    .withValues(alpha: 0.85),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two pills — each rendered IN its own face, so the choice is a live preview.
class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final SpeakType selected;
  final ValueChanged<SpeakType> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Type',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        for (final t in SpeakType.values) ...[
          _TypePill(
            type: t,
            selected: t == selected,
            onTap: () => onChanged(t),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final SpeakType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${type.label} type',
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: StadiumBorder(
          side: selected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            // ≥48dp tap target.
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            child: Text(
              type.label,
              style: TextStyle(
                fontFamily: type.family,
                fontSize: 19,
                color: selected
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontVariations: type.axesAt(selected ? 620 : 460),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pick the presentation mode. Changeable live in performance too — every
/// mode reads the same timeline, so switching is just a different look.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.selected, required this.onChanged});

  final SpeakPresentation selected;
  final ValueChanged<SpeakPresentation> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Show',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in implementedSpeakModes)
              _ModeChip(
                mode: m,
                selected: m == selected,
                onTap: () => onChanged(m),
              ),
          ],
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final SpeakPresentation mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} mode',
      child: Material(
        color: selected
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: selected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mode.icon,
                    size: 18,
                    color: selected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Discloses that the typed text leaves the device for a voice service —
/// and nudges staff away from pasting child PII (audit XC-3).
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your text is sent to a voice service to create the audio — keep '
            "children's names and personal details out of it.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // liveRegion: assistive tech announces the failure when it appears, without
    // the user having to refocus. The "Speak it" button stays enabled, so
    // retry is just tapping again — no separate retry affordance needed.
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
