import 'package:differentworld/app/app.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  runApp(const ProviderScope(child: DifferentWorldApp()));
}
