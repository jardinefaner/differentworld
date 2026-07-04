import 'dart:async';

import 'package:differentworld/features/kid_mode/kid_mode_provider.dart';
import 'package:differentworld/features/world/character_sheet_providers.dart';
import 'package:differentworld/shared/widgets/drawing_pad.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
/// The drawing surface + tools + rasterise are the shared [DrawingController] /
/// [DrawingSurface] / [DrawingTools] (lib/shared/widgets/drawing_pad.dart), so
/// this screen and the Heroes pad draw with one engine. What's LOCAL here is the
/// kid-mode lockdown + the kid-legible top/done chrome.
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
  final DrawingController _controller = DrawingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The kid-legible chrome (undo/clear/done enablement) reflects the drawing.
    _controller.addListener(_onChange);
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

  void _onChange() {
    if (mounted) setState(() {});
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
    _controller
      ..removeListener(_onChange)
      ..dispose();
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

  Future<void> _save() async {
    if (_saving || !_controller.hasDrawing) return;
    setState(() => _saving = true);
    // Capture cross-pop-safe handles BEFORE any await — popping deactivates
    // this element's context (interaction invariant #3).
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final actions = ref.read(characterSheetActionsProvider);
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);

    try {
      final png = await _controller.rasterize(pixelRatio);
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

  @override
  Widget build(BuildContext context) {
    final name = widget.displayName?.trim();
    final title = (name != null && name.isNotEmpty)
        ? 'Draw yourself, $name!'
        : 'Draw yourself!';
    final hasDrawing = _controller.hasDrawing;
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
                onCancel: _saving
                    ? null
                    : () {
                        _leaveKidMode(); // clear the pin before popping (Wave 143)
                        // Imperative pop — bypasses PopScope(canPop:false); the
                        // system back is the thing we block, not the controls.
                        Navigator.of(context).pop();
                      },
                onUndo: _controller.canUndo && !_saving
                    ? _controller.undo
                    : null,
                onClear: hasDrawing && !_saving ? _controller.clear : null,
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: DrawingSurface(controller: _controller),
                    ),
                  ),
                ),
              ),
              DrawingTools(controller: _controller, enabled: !_saving),
              _DoneBar(
                enabled: hasDrawing && !_saving,
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

// ── chrome (kid-legible; the drawing engine lives in drawing_pad.dart) ────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onCancel,
    required this.onUndo,
    required this.onClear,
  });

  final String title;
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
