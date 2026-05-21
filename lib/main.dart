import 'package:differentworld/app/app.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();

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
