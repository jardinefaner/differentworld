import 'package:differentworld/app/app.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use path-based URLs on web (e.g. /differentworld/schedule) instead
  // of hash-fragment URLs (/differentworld/#/schedule). Path URLs look
  // like real URLs, are bookmark-clean, and play correctly with the
  // browser back button. Paired with a copy of index.html as 404.html
  // on the server (handled in .github/workflows/deploy-web.yml) so
  // GitHub Pages serves the Flutter shell for any unknown path —
  // Flutter's go_router then resolves the path client-side.
  //
  // No-op on mobile / desktop.
  usePathUrlStrategy();
  // Wave 107: disable the browser's native right-click context menu
  // on web. Without this, right-clicking any student photo offers
  // "Save Image As…" — bypassing every signed-URL guard and
  // exfiltrating bytes through the browser. Children's data is
  // sensitive PII; this closes the only obvious in-browser leak.
  // On native (iOS/Android/macOS/Windows/Linux) the call is a no-op
  // — it's a `kIsWeb`-guarded BrowserContextMenu API. The Flutter
  // text-selection UI keeps working because we surface our own
  // selection toolbar via SelectionArea (Wave 111).
  if (kIsWeb) {
    await BrowserContextMenu.disableContextMenu();
  }
  await Env.load();
  // Wave 141: prune deprecated prefs keys from older builds so they
  // don't bloat localStorage forever on long-lived web sessions. Add
  // a key here when its read-site is removed from the code.
  await _pruneDeprecatedPrefs();

  // Edge-to-edge: status bar + gesture nav are transparent, content
  // draws under them. Each Scaffold uses extendBody / extendBodyBehindAppBar
  // and a SafeArea on its body so the actual content stays clear of
  // those system surfaces.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      systemNavigationBarDividerColor: Color(0x00000000),
      systemNavigationBarContrastEnforced: false,
    ),
  );

  if (Env.hasSupabase) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      // Default `detectSessionInUri: true` is what we want — on web,
      // Supabase parses the OAuth redirect from the URL on app boot.
    );
  }

  // If a Sentry DSN is configured, route the app through Sentry's
  // runZonedGuarded wrapper so uncaught exceptions + the existing
  // `FlutterError.reportError` calls (signed-URL failures, deeplink
  // parse errors, PowerSync upload failures) end up in the crash
  // reporter. No DSN = `SentryFlutter.init` no-ops and `runApp` runs
  // identically to the pre-Sentry path.
  if (Env.hasSentry) {
    await SentryFlutter.init(
      (options) {
        options
          // Children's data is sensitive — never let user-typed
          // text, URLs, or photo paths reach Sentry's servers
          // verbatim. `sendDefaultPii = false` is the global gate.
          ..dsn = Env.sentryDsn
          ..sendDefaultPii = false
          // Sample 100 % of release crashes (low volume; we want
          // every one). Performance traces stay off until we have
          // a real sampling budget.
          ..tracesSampleRate = 0.0
          // Tag debug vs release in the breadcrumb stream so the
          // dashboard can filter dogfooding noise out.
          ..environment = kDebugMode ? 'debug' : 'release'
          // The before-send hook is the last line of defense
          // against a stray photo path or kid name reaching the
          // network. Today it's a no-op; when we observe real
          // reports we'll add path-stripping logic here.
          ..beforeSend = (event, hint) => event;
      },
      appRunner: () => runApp(
        const ProviderScope(child: DifferentWorldApp()),
      ),
    );
  } else {
    runApp(const ProviderScope(child: DifferentWorldApp()));
  }
}

/// Wave 141: drop SharedPreferences keys that older builds wrote but
/// no current code reads. Cheap idempotent cleanup that prevents
/// dead state from accumulating across long-running browser sessions.
///
/// Add a string to `deadKeys` when a feature that owned a pref is
/// removed. The next launch cleans it up; subsequent launches no-op
/// because the key is already gone.
Future<void> _pruneDeprecatedPrefs() async {
  const deadKeys = <String>{
    // Backfill flag from a removed one-shot data migration. No code
    // reads it anymore (verified via grep on the lib/ tree).
    'incident_child_backfill_v1_done',
  };
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final key in deadKeys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }
  } on Object {
    // Best-effort. A failure here mustn't block boot.
  }
}
