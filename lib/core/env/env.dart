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

  /// Deepgram API key — only needed if you want voice dictation in
  /// the omnibox composer. Without it the mic affordance still shows
  /// but tapping it surfaces a "voice not configured" message.
  ///
  /// SECURITY: ships in the compiled binary; treat as semi-public.
  /// See `docs/SECRETS.md` for the Edge Function broker pattern that
  /// removes the key from the client before external rollout.
  static String get deepgramApiKey => _read('DEEPGRAM_API_KEY');

  /// OpenAI API key — for any AI feature (capture summarization, auto-
  /// tag, drafted progress reports, etc.). Same security caveat as
  /// Deepgram: ships in the binary, set spend caps upstream, broker
  /// through Edge Function before external rollout.
  static String get openAiApiKey => _read('OPENAI_API_KEY');

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  static bool get hasPowerSync => powerSyncUrl.isNotEmpty;
  static bool get hasSentry => sentryDsn.isNotEmpty;
  static bool get hasDeepgram => deepgramApiKey.isNotEmpty;
  static bool get hasOpenAi => openAiApiKey.isNotEmpty;
}
