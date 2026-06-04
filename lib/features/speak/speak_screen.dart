import 'dart:async';

import 'package:differentworld/features/speak/karaoke_view.dart';
import 'package:differentworld/features/speak/speak_service.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/primary_action_button.dart';
import 'package:differentworld/shared/widgets/secondary_action_button.dart';
import 'package:flutter/material.dart';

/// `/speak` — paste any prompt / quote / block, hear it spoken, and watch it
/// in big kinetic karaoke (the Speak feature; docs/FEATURE_CHECKLISTS.md).
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
      _loading = false;
    });
    // Fire-and-forget: play() resolves only at end-of-audio and degrades
    // silently on failure (we've already shown the karaoke view).
    unawaited(_service.play(script));
  }

  void _newText() {
    unawaited(_service.stop());
    setState(() => _script = null);
  }

  @override
  Widget build(BuildContext context) {
    final script = _script;
    return EdgeScaffold(
      // Perform-mode controls live in the top chrome pill — keeps the karaoke
      // full-bleed and clear of the floating omnibox bar at the bottom.
      actions: script == null
          ? const <Widget>[]
          : <Widget>[
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
            ],
      // Input view clears the chrome via SafeArea; the perform view is
      // intentionally full-bleed (chrome floats over the dark stage, like the
      // camera) so the karaoke owns the whole surface.
      body: script == null
          ? SafeArea(bottom: false, child: _input(context))
          : _perform(context, script),
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
              subtitle: 'Paste a prompt, quote, or block — hear it read with '
                  'big karaoke subtitles',
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
            const SizedBox(height: 16),
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
              'A clear, lively voice reads it back and each word lights up as '
              "it's spoken — great for the room, and for emerging readers.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perform(BuildContext context, SpokenScript script) {
    // Full-bleed dark stage; KaraokeView centres the words, so the floating
    // chrome pills (top) and omnibox bar (bottom) clear the content.
    return ColoredBox(
      color: const Color(0xFF0E0F17),
      child: StreamBuilder<Duration>(
        stream: _service.positionStream,
        initialData: Duration.zero,
        builder: (context, snap) => KaraokeView(
          words: script.words,
          position: snap.data ?? Duration.zero,
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
