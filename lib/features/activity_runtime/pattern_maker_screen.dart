import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:differentworld/features/activity_runtime/pattern_maker.dart';
import 'package:differentworld/shared/widgets/content_header.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// `/activity/pattern` — Make a Pattern. Draw or build a tile in real life,
/// snap it, and watch it repeat (kaleidoscope mirroring makes symmetry from
/// any tile). Capture is a one-shot system camera via `image_picker` — no
/// embedded preview, so a plain back exits and there's no kid-lock to get
/// stuck in.
class PatternMakerScreen extends StatefulWidget {
  const PatternMakerScreen({super.key});

  @override
  State<PatternMakerScreen> createState() => _PatternMakerScreenState();
}

class _PatternMakerScreenState extends State<PatternMakerScreen> {
  final ImagePicker _picker = ImagePicker();
  // Wraps the rendered pattern so it can be rasterized into a poster.
  final GlobalKey _patternKey = GlobalKey();
  Uint8List? _tile;
  PatternConfig _config = const PatternConfig();
  int _promptIndex = 0;
  bool _capturing = false;

  String get _prompt => patternPrompts[_promptIndex % patternPrompts.length];

  Future<void> _snap() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (shot == null) return;
      final bytes = await shot.readAsBytes();
      if (!mounted) return;
      setState(() => _tile = bytes);
    } on Object catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open the camera")),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _newPrompt() => setState(() => _promptIndex++);

  /// Rasterize the repeated pattern + open it in the poster tool — print it
  /// wall-sized, or save it (docs/FEATURE_CHECKLISTS.md, the Artifact
  /// contract). The whole save/print/export flow lives in the poster tool.
  Future<void> _makePoster() async {
    if (_capturing) return;
    final boundary =
        _patternKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;
    setState(() => _capturing = true);
    Uint8List? bytes;
    try {
      // pixelRatio 3 → a crisp source for the poster engine's tiling.
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      bytes = data?.buffer.asUint8List();
    } on Object catch (_) {
      bytes = null;
    }
    if (!mounted) return;
    setState(() => _capturing = false);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't make a poster from this pattern"),
        ),
      );
      return;
    }
    unawaited(context.push('/poster', extra: bytes));
  }

  @override
  Widget build(BuildContext context) {
    final tile = _tile;
    return EdgeScaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          children: [
            const ContentHeader(
              title: 'Make a Pattern',
            ),
            if (tile == null)
              _Intro(
                prompt: _prompt,
                capturing: _capturing,
                onSnap: _snap,
                onNewPrompt: _newPrompt,
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  // RepaintBoundary so _makePoster can rasterize the clean
                  // square pattern (the rounded clip is display-only).
                  child: RepaintBoundary(
                    key: _patternKey,
                    child: PatternCanvas(tile: tile, config: _config),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _Controls(
                config: _config,
                capturing: _capturing,
                onConfig: (c) => setState(() => _config = c),
                onNewTile: _snap,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _capturing ? null : _makePoster,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                icon: const Icon(Icons.print_outlined),
                label: const Text(
                  'Make a poster',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The pre-capture state — the prompt (the "rule") + the big Snap button.
class _Intro extends StatelessWidget {
  const _Intro({
    required this.prompt,
    required this.capturing,
    required this.onSnap,
    required this.onNewPrompt,
  });

  final String prompt;
  final bool capturing;
  final VoidCallback onSnap;
  final VoidCallback onNewPrompt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.onSecondaryContainer,
              ),
              const SizedBox(height: 16),
              Text(
                prompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onNewPrompt,
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: const Text('Another idea'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: capturing ? null : onSnap,
          // minimumSize (not a fixed-height SizedBox) so the label can grow
          // at 200% text scale without clipping (rubric E3).
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
          ),
          icon: capturing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera, size: 26),
          label: Text(
            capturing ? 'Opening…' : 'Snap your tile',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Post-capture controls — density + kaleidoscope + re-snap.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.config,
    required this.capturing,
    required this.onConfig,
    required this.onNewTile,
  });

  final PatternConfig config;
  final bool capturing;
  final ValueChanged<PatternConfig> onConfig;
  final VoidCallback onNewTile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Repeat', style: theme.textTheme.labelLarge),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                children: [
                  for (final n in patternTileChoices)
                    ChoiceChip(
                      label: Text('$n×$n'),
                      selected: config.tilesPerRow == n,
                      // Keep the hit-box ≥ 48 dp (rubric E1) — these are the
                      // primary post-capture control, often a kid's target.
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) =>
                          onConfig(config.copyWith(tilesPerRow: n)),
                    ),
                ],
              ),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kaleidoscope'),
          subtitle: const Text('Mirror the tile into symmetry'),
          value: config.kaleidoscope,
          onChanged: (v) => onConfig(config.copyWith(kaleidoscope: v)),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: capturing ? null : onNewTile,
          icon: const Icon(Icons.replay),
          label: const Text('New tile'),
        ),
      ],
    );
  }
}

/// The magic: one tile, repeated into a [PatternConfig.tilesPerRow] square,
/// with optional mirror so the tiles meet edge-to-edge. Each cell is its own
/// `Image.memory` — Flutter's image cache de-dupes by bytes, so all cells
/// share one decode.
class PatternCanvas extends StatelessWidget {
  const PatternCanvas({required this.tile, required this.config, super.key});

  final Uint8List tile;
  final PatternConfig config;

  @override
  Widget build(BuildContext context) {
    final n = config.tilesPerRow;
    return Column(
      children: [
        for (var r = 0; r < n; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < n; c++)
                  Expanded(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.diagonal3Values(
                        config.flipX(c) ? -1.0 : 1.0,
                        config.flipY(r) ? -1.0 : 1.0,
                        1,
                      ),
                      child: Image.memory(
                        tile,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
