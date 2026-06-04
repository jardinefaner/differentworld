import 'dart:async';

import 'package:differentworld/features/speak/speak_service.dart';
import 'package:differentworld/features/speak/speak_stage.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
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
  SpeakType _type = SpeakType.serif;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_service.dispose());
    super.dispose();
  }

  Future<void> _speak() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    // Dismiss the keyboard before we (may) swap to the full-bleed perform
    // view — otherwise the IME can linger open behind it on Android.
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final SpokenScript script;
    try {
      script = await _service.synthesize(text: text);
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'speak'),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't voice that. The ElevenLabs voice may not be set up "
            'yet, or you might be offline.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _script = script;
      _lines = linesFromWords(script.words);
      _loading = false;
    });
    // Fire-and-forget: play() resolves only at end-of-audio and degrades
    // silently on failure (we've already shown the stage).
    unawaited(_service.play(script));
  }

  void _newText() {
    unawaited(_service.stop());
    setState(() => _script = null);
  }

  void _toggleType() => setState(() => _type = _type.other);

  @override
  Widget build(BuildContext context) {
    final performing = _script != null;
    return EdgeScaffold(
      // Perform-mode controls live in the top chrome pill — keeps the stage
      // full-bleed and clear of the floating omnibox bar at the bottom.
      actions: performing
          ? <Widget>[
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
              subtitle: 'Paste a prompt, quote, or block — hear it read aloud '
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
            const SizedBox(height: 18),
            _TypeSelector(
              selected: _type,
              onChanged: (t) => setState(() => _type = t),
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
              'A clear voice reads it back while each line takes the stage — the '
              'spoken word swells. Switch the type any time; pick the one that '
              'feels right.',
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
    // Full-bleed dark stage; SpeakStage centres the line, so the floating
    // chrome pills (top) and omnibox bar (bottom) clear the type.
    return ColoredBox(
      color: const Color(0xFF0E0F17),
      child: _SpeakStageHost(
        service: _service,
        lines: _lines,
        type: _type,
      ),
    );
  }
}

/// Drives [SpeakStage] from a per-frame ticker that reads the player's exact
/// position, so word/line flips land on the voice rather than up to 200ms
/// late (the position STREAM is only ~5/sec). Rebuilds only when the active
/// line or word actually changes — the implicit weight + line-swap animations
/// interpolate smoothly between those discrete flips.
class _SpeakStageHost extends StatefulWidget {
  const _SpeakStageHost({
    required this.service,
    required this.lines,
    required this.type,
  });

  final SpeakService service;
  final List<SpokenLine> lines;
  final SpeakType type;

  @override
  State<_SpeakStageHost> createState() => _SpeakStageHostState();
}

class _SpeakStageHostState extends State<_SpeakStageHost>
    with SingleTickerProviderStateMixin {
  late final _ticker = createTicker(_onTick);
  Duration _position = Duration.zero;
  int _line = -1;
  int _word = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_ticker.start());
  }

  void _onTick(Duration _) {
    final pos = widget.service.currentPosition;
    final line = lineIndexAt(widget.lines, pos);
    final word =
        line < 0 ? -1 : currentWordIndex(widget.lines[line].words, pos);
    if (line != _line || word != _word) {
      setState(() {
        _position = pos;
        _line = line;
        _word = word;
      });
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpeakStage(
      lines: widget.lines,
      position: _position,
      type: widget.type,
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
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
