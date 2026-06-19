import 'dart:async';
import 'dart:ui' as ui;

import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/world/character_sheet_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// `/subjects/:id/draw` — the **first slice of Different World**: a child draws
/// themselves, and that drawing becomes their face in the app (the subject's
/// avatar). See docs/WORLD.md (the vision) + docs/WORLD_DESIGN.md (slice 1).
///
/// A full-bleed kid surface: it enters kid mode (AppShell strips the omnibox +
/// chrome) and pins the locked route so a stray system-back / browser-back
/// can't drift the kid into staff screens. The only ways out are the visible
/// **Cancel** and **Done** controls — both staff-and-kid legible.
///
/// On Done the canvas is rasterised (RepaintBoundary → PNG) and saved as the
/// world-self avatar via `CharacterSheetActions.setDrawnAvatar` — which routes
/// through the SAME photo pipeline every avatar uses (compression, the
/// space-scoped private bucket, signed-URL reads, the offline upload queue)
/// but writes to `character_sheets.avatar_url`, NOT the subject's admin photo.
class DrawSelfScreen extends ConsumerStatefulWidget {
  const DrawSelfScreen({
    required this.subjectId,
    this.displayName,
    super.key,
  });

  /// From the path — the only thing we strictly need (drives the upload). A
  /// kid-mode bounce-back rebuilds the route without `extra`, so the screen
  /// must work from this alone.
  final String subjectId;

  /// Cosmetic ("Draw yourself, {name}!"). From `extra`; null on a deep link.
  final String? displayName;

  @override
  ConsumerState<DrawSelfScreen> createState() => _DrawSelfScreenState();
}

class _DrawSelfScreenState extends ConsumerState<DrawSelfScreen>
    with WidgetsBindingObserver {
  // Cached in initState — a plain read there is safe, but `ref` in dispose is
  // not (Riverpod: "save the provider state in a field"). The KidModeLock mixin
  // caches for the same reason.
  late final KidMode _kidMode;
  late final KidModeLockedRoute _lockedRoute;
  final GlobalKey _canvasKey = GlobalKey();
  final List<_Stroke> _strokes = <_Stroke>[];
  _Stroke? _active;
  Color _color = _palette.first;
  double _width = _widths[1];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cache the notifiers now (a plain read in initState is safe). The .enter()
    // WRITE still defers to a microtask: a sync write during the parent route's
    // build trips Riverpod's "modified during build" assertion (AppShell
    // watches kidModeProvider). try/catch so a briefly unhealthy wire can't
    // bubble to the top-level error handler.
    _kidMode = ref.read(kidModeProvider.notifier);
    _lockedRoute = ref.read(kidModeLockedRouteProvider.notifier);
    unawaited(
      Future.microtask(() {
        if (!mounted) return;
        try {
          _kidMode.enter();
          _lockedRoute.pin('/subjects/${widget.subjectId}/draw');
        } on Object catch (e, st) {
          if (kDebugMode) {
            debugPrint('[draw-self] initState microtask failed: $e\n$st');
          }
        }
      }),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Re-engage kid mode if the OS resurrected the Activity without rebuilding
    // (so a backgrounded-then-resumed draw screen can't expose staff chrome).
    if (state == AppLifecycleState.resumed && mounted) {
      _kidMode.enter();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Idempotent belt-and-suspenders — the exit paths already clear these
    // before popping (see _leaveKidMode); this covers an OS-forced teardown.
    _kidMode.exit();
    _lockedRoute.pin(null);
    super.dispose();
  }

  /// Clear kid mode + the locked-route pin. MUST run before any pop: the
  /// router redirect bounces away-navigation back to the pinned route, so
  /// popping with the pin still set traps the screen (Wave 143 gotcha,
  /// documented in survey_take_screen.dart). exit()/pin(null) are idempotent.
  void _leaveKidMode() {
    ref.read(kidModeProvider.notifier).exit();
    ref.read(kidModeLockedRouteProvider.notifier).pin(null);
  }

  void _startStroke(Offset p) {
    setState(() {
      _active = _Stroke(color: _color, width: _width, points: <Offset>[p]);
    });
  }

  void _extendStroke(Offset p) {
    final active = _active;
    if (active == null) return;
    setState(() => active.points.add(p));
  }

  void _endStroke() {
    final active = _active;
    if (active == null) return;
    setState(() {
      _strokes.add(active);
      _active = null;
    });
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    _strokes.removeLast();
    setState(() {});
  }

  void _clear() {
    if (_strokes.isEmpty && _active == null) return;
    setState(() {
      _strokes.clear();
      _active = null;
    });
  }

  bool get _hasDrawing => _strokes.isNotEmpty;

  Future<void> _save() async {
    if (_saving || !_hasDrawing) return;
    setState(() => _saving = true);
    // Capture cross-pop-safe handles BEFORE any await — popping deactivates
    // this element's context (interaction invariant #3).
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(characterSheetActionsProvider);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    try {
      final png = await _rasterize(pixelRatio);
      if (png == null) {
        throw StateError('Could not capture the drawing.');
      }
      final file = XFile.fromData(
        png,
        mimeType: 'image/png',
        name: 'self.png',
      );
      // The world-self avatar — SEPARATE from the subject's admin photo.
      await actions.setDrawnAvatar(
        subjectId: widget.subjectId,
        drawing: file,
      );
      if (!mounted) {
        // OS killed the screen mid-save (near-impossible under the kid-mode
        // lock). The write already landed; dispose() clears kid mode. Don't
        // touch ref / navigator on a dead element.
        messenger.showSnackBar(
          const SnackBar(content: Text('Saved your drawing!')),
        );
        return;
      }
      // Clear the locked-route pin + kid mode BEFORE popping — the router's
      // redirect bounces away-navigation back to the pinned route, so popping
      // with the pin still set traps the screen (the Wave 143 gotcha).
      _leaveKidMode();
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Saved your drawing!')),
      );
    } on Object catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'draw-self'),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't save the drawing — try again.")),
      );
    }
  }

  Future<Uint8List?> _rasterize(double pixelRatio) async {
    final boundary =
        _canvasKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    // Cap the raster scale — uploadAndPersist re-encodes to ≤1024px JPEG
    // anyway, and a huge pixelRatio on a big tablet is wasted work.
    final scale = pixelRatio.clamp(1.0, 3.0);
    final image = await boundary.toImage(pixelRatio: scale);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName?.trim();
    final title = (name != null && name.isNotEmpty)
        ? 'Draw yourself, $name!'
        : 'Draw yourself!';
    // Intentionally a RAW Scaffold, not EdgeScaffold — this is a full-bleed
    // kid surface. Kid mode strips AppShell's omnibox + chrome, and this
    // screen draws its own top bar + tools. Switching to EdgeScaffold would
    // inject chrome insets that fight the lockdown (and flash the floating
    // pills during the mount microtask gap). See CLAUDE.md "kid mode" +
    // docs/SCREEN_RUBRIC.md full-bleed exception.
    return PopScope(
      // System-back is BLOCKED so a kid can't drift into staff screens. The
      // visible Cancel / Done controls leave via imperative pop (which
      // bypasses this). Two layers, per the survey_take rule: PopScope catches
      // the Flutter system-back; the kidModeLockedRoute pin catches go_router
      // nav. This screen had only the pin — the back-block was the gap.
      canPop: false,
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        backgroundColor: const Color(0xFF2B2A33),
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: title,
                canEdit: _hasDrawing && !_saving,
                onCancel: _saving
                    ? null
                    : () {
                        _leaveKidMode(); // clear the pin before popping (Wave 143)
                        // Imperative pop — bypasses PopScope(canPop:false); the
                        // system back is the thing we block, not the controls.
                        Navigator.of(context).pop();
                      },
                onUndo: _strokes.isNotEmpty && !_saving ? _undo : null,
                onClear: _hasDrawing && !_saving ? _clear : null,
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _Canvas(
                        canvasKey: _canvasKey,
                        strokes: _strokes,
                        active: _active,
                        onStart: _startStroke,
                        onUpdate: _extendStroke,
                        onEnd: _endStroke,
                      ),
                    ),
                  ),
                ),
              ),
              _Tools(
                palette: _palette,
                widths: _widths,
                color: _color,
                width: _width,
                enabled: !_saving,
                onColor: (c) => setState(() => _color = c),
                onWidth: (w) => setState(() => _width = w),
              ),
              _DoneBar(
                enabled: _hasDrawing && !_saving,
                saving: _saving,
                onDone: () => unawaited(_save()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── the canvas ──────────────────────────────────────────────────────────────

class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.canvasKey,
    required this.strokes,
    required this.active,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final GlobalKey canvasKey;
  final List<_Stroke> strokes;
  final _Stroke? active;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary serves double duty: it isolates the canvas' repaints
    // from the rest of the screen AND is what we rasterise on Done.
    return RepaintBoundary(
      key: canvasKey,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: GestureDetector(
          onPanStart: (d) => onStart(d.localPosition),
          onPanUpdate: (d) => onUpdate(d.localPosition),
          onPanEnd: (_) => onEnd(),
          child: CustomPaint(
            painter: _DrawingPainter(strokes: strokes, active: active),
            // A finite size so the paint area fills the square; AspectRatio
            // already bounds it.
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _DrawingPainter extends CustomPainter {
  _DrawingPainter({required this.strokes, required this.active});

  final List<_Stroke> strokes;
  final _Stroke? active;

  // Warm paper. MUST be opaque: uploadAndPersist re-encodes to JPEG, which has
  // no alpha — a transparent background would otherwise composite to black.
  static const Color _paper = Color(0xFFFFFDF7);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _paper);
    for (final stroke in strokes) {
      _paintStroke(canvas, stroke);
    }
    final a = active;
    if (a != null) _paintStroke(canvas, a);
  }

  void _paintStroke(Canvas canvas, _Stroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final points = stroke.points;
    if (points.isEmpty) return;
    if (points.length == 1) {
      // A tap = a dot. Draw a filled circle so it isn't invisible.
      canvas.drawCircle(
        points.first,
        stroke.width / 2,
        Paint()..color = stroke.color,
      );
      return;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_DrawingPainter old) =>
      old.strokes != strokes ||
      old.active != active ||
      old.active?.points.length != active?.points.length;
}

class _Stroke {
  _Stroke({required this.color, required this.width, required this.points});
  final Color color;
  final double width;
  final List<Offset> points;
}

// ── chrome ───────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.canEdit,
    required this.onCancel,
    required this.onUndo,
    required this.onClear,
  });

  final String title;
  final bool canEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Cancel',
            onPressed: onCancel,
            icon: const Icon(Icons.close, color: Colors.white),
            iconSize: 28,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Undo',
            onPressed: onUndo,
            icon: const Icon(Icons.undo, color: Colors.white),
            iconSize: 26,
          ),
          IconButton(
            tooltip: 'Clear',
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            iconSize: 26,
          ),
        ],
      ),
    );
  }
}

class _Tools extends StatelessWidget {
  const _Tools({
    required this.palette,
    required this.widths,
    required this.color,
    required this.width,
    required this.enabled,
    required this.onColor,
    required this.onWidth,
  });

  final List<Color> palette;
  final List<double> widths;
  final Color color;
  final double width;
  final bool enabled;
  final ValueChanged<Color> onColor;
  final ValueChanged<double> onWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Colors.
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: palette.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final c = palette[i];
                final selected = c == color;
                // The last swatch is paper-coloured — it erases against the
                // paper. Name it so VoiceOver doesn't read "Color 10".
                final isErase = i == palette.length - 1;
                return Semantics(
                  label: isErase ? 'Erase' : 'Color ${i + 1}',
                  selected: selected,
                  button: true,
                  // 48 dp hit target (rubric E1); 44 dp visible circle inside.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onColor(c) : null,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.white : Colors.white24,
                              width: selected ? 4 : 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Brush thickness.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final w in widths) ...[
                Semantics(
                  label: 'Brush size ${widths.indexOf(w) + 1}',
                  selected: w == width,
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: enabled ? () => onWidth(w) : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: w == width ? Colors.white24 : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Container(
                        width: w + 6,
                        height: w + 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DoneBar extends StatelessWidget {
  const _DoneBar({
    required this.enabled,
    required this.saving,
    required this.onDone,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: enabled ? onDone : null,
          icon: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(
            saving ? 'Saving…' : "That's me!",
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

// Fat, bold, kid-legible. White last (an "eraser" against the warm paper).
const List<Color> _palette = <Color>[
  Color(0xFF1A1A1A), // near-black
  Color(0xFFE53935), // red
  Color(0xFFFB8C00), // orange
  Color(0xFFFDD835), // yellow
  Color(0xFF43A047), // green
  Color(0xFF1E88E5), // blue
  Color(0xFF8E24AA), // purple
  Color(0xFF6D4C41), // brown
  Color(0xFFEC407A), // pink
  Color(0xFFFFFDF7), // paper (erase)
];

const List<double> _widths = <double>[6, 12, 22];
