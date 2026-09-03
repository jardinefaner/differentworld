/// Opens the sandbox's throwaway database, per platform.
///
/// **This file exists to keep `dart:ffi` out of the web build.**
/// `NativeDatabase` (drift/native.dart) transitively imports `dart:ffi`, which
/// dart2js cannot compile — so a single unconditional import of it anywhere
/// REACHABLE from `main()` fails the whole web build with
/// "Dart library 'dart:ffi' is not available on this platform".
///
/// That is exactly what happened when the sandbox was first routed: it had
/// been orphaned, so its `drift/native.dart` import never entered the web
/// graph, and wiring it into the router broke `flutter build web` on a file
/// nobody had edited. Conditional import is the fix, and the reason this
/// indirection is worth its three files.
library;

export 'sandbox_db_native.dart'
    if (dart.library.js_interop) 'sandbox_db_web.dart';
