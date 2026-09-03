import 'dart:async';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/core/db/drift_provider.dart';
import 'package:differentworld/core/viewer/viewer.dart';
import 'package:differentworld/features/sandbox/sandbox_data.dart';
import 'package:differentworld/features/sandbox/sandbox_db.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which pretend staffer you are inside the sandbox. Null = not in one.
final sandboxMemberIdProvider = NotifierProvider<SandboxMember, String?>(
  SandboxMember.new,
);

class SandboxMember extends Notifier<String?> {
  @override
  String? build() => null;

  /// `enterAs` reads as an action at the call site, which is what entering
  /// a sandbox is; a setter named `member` would not.
  // ignore: use_setters_to_change_properties
  void enterAs(String memberId) => state = memberId;

  void leave() => state = null;
}

/// Runs [child] against a THROWAWAY in-memory database seeded with a
/// pretend program.
///
/// This is the difference between role preview and a sandbox. Preview swaps
/// your capabilities but keeps your member id, so your room assignments stay
/// yours — which is why previewing as a counselor usually shows an empty
/// room list. Here you become a real member of a real (pretend) room, so
/// what you see is what that person's Monday actually looks like.
///
/// **It cannot reach a real program, structurally.** The database is
/// `NativeDatabase.memory()` with no PowerSync connector attached, so rows
/// written here have nowhere to sync TO — there is no code path from this
/// data to the server. That is what makes it safe to let anyone poke at
/// without a warning dialog: the worst case is that they change something
/// that evaporates.
class SandboxScope extends ConsumerStatefulWidget {
  const SandboxScope({
    required this.child,
    this.day = SandboxDay.running,
    super.key,
  });

  final Widget child;

  /// Which pretend program to build — a running Monday, or a brand-new
  /// program's first screen.
  final SandboxDay day;

  @override
  ConsumerState<SandboxScope> createState() => _SandboxScopeState();
}

class _SandboxScopeState extends ConsumerState<SandboxScope> {
  AppDatabase? _db;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_build());
  }

  Future<void> _build() async {
    try {
      final db = AppDatabase.detached(openSandboxDatabase());
      await db.materializeSchema();
      await seedSandbox(
        db,
        nowIso: DateTime.now().toUtc().toIso8601String(),
        day: widget.day,
      );
      // The screen can pop while the seed is still running — close the
      // database rather than leaking it, and do not touch State after that.
      if (!mounted) {
        await db.close();
        return;
      }
      setState(() => _db = db);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    // The whole point evaporates on exit. Nothing to clean up server-side
    // because nothing ever left this object.
    unawaited(_db?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return const Center(child: Text("Couldn't build the sandbox."));
    }
    final db = _db;
    if (db == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWith((ref) async => db),
      ],
      child: widget.child,
    );
  }
}

/// The pretend staffer you are, resolved against the sandbox database.
///
/// Declared here rather than in the scope so a caller can read it without
/// depending on the widget.
Viewer sandboxViewer(List<Member> members, List<Space> spaces, String id) {
  final member = members.where((m) => m.id == id).firstOrNull;
  final space = spaces.where((s) => s.id == sandboxSpaceId).firstOrNull;
  return Viewer(member: member, space: space);
}
