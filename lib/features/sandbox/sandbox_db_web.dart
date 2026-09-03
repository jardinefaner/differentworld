import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:sqlite3/wasm.dart';

/// Web: the same in-memory database, through sqlite3 compiled to WASM.
///
/// `sqlite3.wasm` is already served from `web/` for PowerSync's own local
/// database (`dart run powersync:setup_web` puts it there), so this adds no
/// new asset — it reuses the one the app already ships.
///
/// [LazyDatabase] because loading the WASM module is async and the sandbox
/// wants a synchronous [QueryExecutor]; drift opens it on first query.
/// An in-memory VFS, registered as default, keeps it off OPFS — a throwaway
/// program must not outlive its screen or collide with the real local db.
QueryExecutor openSandboxDatabase() => LazyDatabase(() async {
  final sqlite3 = await WasmSqlite3.loadFromUrl(Uri.parse('sqlite3.wasm'));
  sqlite3.registerVirtualFileSystem(InMemoryFileSystem(), makeDefault: true);
  return WasmDatabase.inMemory(sqlite3);
});
