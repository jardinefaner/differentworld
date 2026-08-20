// Plain passthrough test config for this directory. The repo root's
// flutter_test_config.dart wires the golden-file comparator, which doesn't
// compile on the web platform — and these tests exist precisely to run with
// `flutter test --platform chrome test/web_smoke` (kIsWeb = true), catching
// web-only runtime breaks like Isolate.run in a shared code path.
import 'dart:async';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
