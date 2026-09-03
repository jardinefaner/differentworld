import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// Mobile + desktop: an in-memory SQLite via FFI. Nothing touches disk, so the
/// pretend program evaporates when the screen pops.
QueryExecutor openSandboxDatabase() => NativeDatabase.memory();
