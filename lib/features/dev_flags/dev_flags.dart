import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

/// A DEV-ONLY "flag this screen" record. The user taps the floating flag to
/// bookmark a screen they want the next Claude Code session to look at — no
/// more "go back and find the screen I meant." We read these back with
/// `scripts/read_dev_flags.sh` (adb run-as the JSON off the debug build).
///
/// Not a product feature: the button + this whole file are gated on
/// [kDebugMode], so nothing ships in a release build.
@immutable
class DevFlag {
  const DevFlag({
    required this.route,
    required this.label,
    required this.note,
    required this.at,
  });

  factory DevFlag.fromJson(Map<String, dynamic> j) => DevFlag(
    route: j['route'] as String? ?? '',
    label: j['label'] as String? ?? '',
    note: j['note'] as String? ?? '',
    at: j['at'] as String? ?? '',
  );

  /// The exact active route (`uri.path`, ids and all) — what tells Claude
  /// which screen + entity to open.
  final String route;

  /// A friendly label (the route's last segment) for the toast.
  final String label;

  /// Optional free-text "why I flagged it" the user can add from the toast.
  final String note;

  /// ISO timestamp — also the stable key for annotating this exact flag.
  final String at;

  Map<String, dynamic> toJson() => {
    'route': route,
    'label': label,
    'note': note,
    'at': at,
  };
}

/// Append-only store at `<app-docs>/dw_flags.json`. Read-modify-write — fine
/// for a single-user debug tool.
abstract final class DevFlagStore {
  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/dw_flags.json');
  }

  static Future<List<DevFlag>> all() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return [];
      final list = jsonDecode(await f.readAsString()) as List<dynamic>;
      return [
        for (final x in list) DevFlag.fromJson(x as Map<String, dynamic>),
      ];
    } on Object {
      return [];
    }
  }

  static Future<void> _write(List<DevFlag> flags) async {
    final f = await _file();
    await f.writeAsString(jsonEncode([for (final x in flags) x.toJson()]));
  }

  static Future<void> add(DevFlag flag) async {
    final list = await all()
      ..add(flag);
    await _write(list);
    if (kDebugMode) debugPrint('[DW-FLAG] ${flag.route}');
  }

  /// Annotate the flag with this exact [at] (the toast's "Add note" path).
  static Future<void> note(String at, String note) async {
    final list = await all();
    final i = list.indexWhere((f) => f.at == at);
    if (i < 0) return;
    final f = list[i];
    list[i] = DevFlag(route: f.route, label: f.label, note: note, at: f.at);
    await _write(list);
    if (kDebugMode) debugPrint('[DW-FLAG note] ${f.route} | $note');
  }
}

/// The floating flag affordance. Render it ONLY in debug — AppShell gates it.
class DevFlagButton extends StatelessWidget {
  const DevFlagButton({super.key});

  String _labelFor(String route) {
    final segs = route.split('/').where((s) => s.isNotEmpty).toList();
    return segs.isEmpty ? 'home' : segs.last;
  }

  Future<void> _flag(BuildContext context) async {
    final route = GoRouterState.of(context).uri.path;
    final at = DateTime.now().toIso8601String();
    final flag = DevFlag(
      route: route,
      label: _labelFor(route),
      note: '',
      at: at,
    );
    final messenger = ScaffoldMessenger.of(context);
    unawaited(HapticFeedback.mediumImpact());
    await DevFlagStore.add(flag);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Flagged $route'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Add note',
          onPressed: () => unawaited(_addNote(context, at)),
        ),
      ),
    );
  }

  Future<void> _addNote(BuildContext context, String at) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Why flag this?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'e.g. the verbs chip is misaligned here',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Skip'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null && note.trim().isNotEmpty) {
      await DevFlagStore.note(at, note.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Flag this screen for review',
      child: Material(
        color: scheme.secondaryContainer.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => unawaited(_flag(context)),
          child: Padding(
            padding: const EdgeInsets.all(11),
            child: Icon(
              Icons.outlined_flag,
              size: 22,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
