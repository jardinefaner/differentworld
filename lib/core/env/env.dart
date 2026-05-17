import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class Env {
  static Future<void> load() => dotenv.load();

  static String _read(String key) {
    // Tolerate calls before `Env.load()` (e.g. widget tests).
    try {
      return dotenv.env[key] ?? '';
    } on Object {
      return '';
    }
  }

  static String get supabaseUrl => _read('SUPABASE_URL');
  static String get supabaseAnonKey => _read('SUPABASE_ANON_KEY');
  static String get powerSyncUrl => _read('POWERSYNC_URL');
  static String get sentryDsn => _read('SENTRY_DSN');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasPowerSync => powerSyncUrl.isNotEmpty;
  static bool get hasSentry => sentryDsn.isNotEmpty;
}
