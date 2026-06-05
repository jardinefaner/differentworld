import 'dart:async';

import 'package:differentworld/features/speak/collage_view.dart';
import 'package:differentworld/features/speak/editorial_view.dart';
import 'package:differentworld/features/speak/grid_view.dart';
import 'package:differentworld/features/speak/index_view.dart';
import 'package:differentworld/features/speak/justified_view.dart';
import 'package:differentworld/features/speak/living_background.dart';
import 'package:differentworld/features/speak/mural_view.dart';
import 'package:differentworld/features/speak/one_big_word_view.dart';
import 'package:differentworld/features/speak/shape_view.dart';
import 'package:differentworld/features/speak/speak_palette.dart';
import 'package:differentworld/features/speak/speak_presentation.dart';
import 'package:differentworld/features/speak/speak_service.dart';
import 'package:differentworld/features/speak/speak_stage.dart';
import 'package:differentworld/features/speak/spoken_script.dart';
import 'package:differentworld/features/speak/spotlight_view.dart';
import 'package:differentworld/features/speak/stack_view.dart';
import 'package:differentworld/features/speak/type_theme.dart';
import 'package:differentworld/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';

/// Drives [SpeakStage] from a per-frame ticker that reads the player's exact
/// position, so word/line flips land on the voice rather than up to 200ms
/// late (the position STREAM is only ~5/sec). Also owns playback CONTROL: tap
/// the stage to pause/resume; the ticker idles when not playing (no 60fps
/// spin after the voice ends); a finished performance shows a tap-to-replay
/// glyph. Rebuilds only when the active line/word changes — the implicit
/// animations interpolate smoothly between those discrete flips.
class SpeakPerformer extends StatefulWidget {
  const SpeakPerformer({
    required this.service,
    required this.mode,
    required this.lines,
    required this.words,
    required this.type,
    required this.palette,
    super.key,
  });

  final SpeakService service;
  final SpeakPresentation mode;
  final List<SpokenLine> lines;
  final List<SpokenWord> words;
  final SpeakType type;
  final SpeakPalette palette;

  @override
  State<SpeakPerformer> createState() => _SpeakPerformerState();
}

class _SpeakPerformerState extends State<SpeakPerformer>
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
  // Set before the ticker is disposed — a stream event arriving in the
  // cancel→dispose window must not touch the dead ticker.
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _playSub = widget.service.playingStream.listen(_onPlayingChanged);
    _doneSub = widget.service.completedStream.listen(_onCompleted);
  }

  void _onPlayingChanged(bool playing) {
    if (_disposed || !mounted) return;
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
    if (_disposed || !mounted || !completed) return;
    if (_ticker.isActive) _ticker.stop();
    setState(() {
      _done = true;
      _playing = false;
    });
  }

  void _onTick(Duration _) {
    if (_disposed) return;
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
    _disposed = true;
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
      SpeakPresentation.editorial => EditorialView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.oneBigWord => OneBigWordView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.stack => StackView(
        lines: widget.lines,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.collage => CollageView(
        lines: widget.lines,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.spotlight => SpotlightView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.mural => MuralView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.grid => WordGridView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.justified => JustifiedView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.contents => IndexView(
        lines: widget.lines,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.shape => ShapeView(
        words: widget.words,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
      SpeakPresentation.stage => SpeakStage(
        lines: widget.lines,
        position: _position,
        type: widget.type,
        accent: widget.palette.accent,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Show the pause glyph only once playback has actually begun — never
    // during the initial load (which would flash "paused" before the voice
    // starts).
    final paused = _started && !_playing && !_done;
    return LivingBackground(
      palette: widget.palette,
      animate: _playing, // freeze the drift while paused / done (battery)
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
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
            ),
          ),
          // Transport — play/pause, a drag-to-seek scrubber, time. Sits at the
          // bottom (the omnibox bar is hidden during the performance).
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _TransportBar(
              service: widget.service,
              playing: _playing,
              done: _done,
              accent: widget.palette.accent,
              onPlayPause: _toggle,
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtTime(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// The media transport — play/pause/replay, a drag-to-seek scrubber, and
/// elapsed/total time. Subscribes to the position stream itself (the stage's
/// ticker is for word-flips; this only needs ~5/sec).
class _TransportBar extends StatefulWidget {
  const _TransportBar({
    required this.service,
    required this.playing,
    required this.done,
    required this.accent,
    required this.onPlayPause,
  });

  final SpeakService service;
  final bool playing;
  final bool done;
  final Color accent;
  final VoidCallback onPlayPause;

  @override
  State<_TransportBar> createState() => _TransportBarState();
}

class _TransportBarState extends State<_TransportBar> {
  // Non-null while dragging the scrubber, so it doesn't snap back to the
  // streamed position mid-drag.
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(color: Colors.white70, fontSize: 12);
    final icon = widget.done
        ? Icons.replay_rounded
        : widget.playing
        ? Icons.pause_rounded
        : Icons.play_arrow_rounded;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: GlassPanel(
          shape: GlassPanelShape.bar,
          child: StreamBuilder<Duration>(
            stream: widget.service.positionStream,
            initialData: Duration.zero,
            builder: (context, snap) {
              final pos = snap.data ?? Duration.zero;
              final dur = widget.service.duration ?? Duration.zero;
              final maxMs = dur.inMilliseconds.toDouble();
              final posMs = pos.inMilliseconds.toDouble();
              final value = (_dragMs ?? posMs).clamp(
                0.0,
                maxMs <= 0 ? 1 : maxMs,
              );
              final shown = _dragMs != null
                  ? Duration(milliseconds: _dragMs!.round())
                  : pos;
              return Row(
                children: [
                  IconButton(
                    onPressed: widget.onPlayPause,
                    icon: Icon(icon, color: Colors.white),
                    tooltip: widget.playing ? 'Pause' : 'Play',
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(_fmtTime(shown), style: labelStyle),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: widget.accent,
                        thumbColor: widget.accent,
                        inactiveTrackColor: Colors.white24,
                        trackHeight: 2.5,
                        // Default overlay radius (24 → 48dp touch target); the
                        // old custom 14 made the thumb hard to grab.
                      ),
                      child: Slider(
                        value: value.toDouble(),
                        max: maxMs <= 0 ? 1 : maxMs,
                        onChanged: (v) => setState(() => _dragMs = v),
                        onChangeEnd: (v) {
                          unawaited(
                            widget.service.seek(
                              Duration(milliseconds: v.round()),
                            ),
                          );
                          setState(() => _dragMs = null);
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 38,
                    child: Text(
                      _fmtTime(dur),
                      style: labelStyle,
                      textAlign: TextAlign.end,
                    ),
                  ),
                  // Keep the total time off the very edge.
                  const SizedBox(width: 10),
                ],
              );
            },
          ),
        ),
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
