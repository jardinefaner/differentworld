import 'package:differentworld/app/app.dart';
import 'package:differentworld/core/env/env.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();

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
