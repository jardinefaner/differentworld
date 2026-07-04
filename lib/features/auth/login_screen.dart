import 'package:differentworld/core/auth/auth_providers.dart';
import 'package:differentworld/shared/widgets/dw_wordmark.dart';
import 'package:differentworld/shared/widgets/horizon_mark.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _signingIn = false;
  String? _error;

  Future<void> _signInWithGoogle() async {
    if (_signingIn) return;
    setState(() {
      _signingIn = true;
      _error = null;
    });
    try {
      await ref
          .read(supabaseProvider)
          .auth
          .signInWithOAuth(
            OAuthProvider.google,
            // Web: bounce back to the CURRENT page (without any query
            // string / fragment). `redirectTo: null` would make
            // Supabase fall back to the dashboard's Site URL, which
            // is `localhost:3000` for local dev — sending the user
            // there after a github.io OAuth produces a Safari "can't
            // connect to localhost" page. Building the URL from
            // `Uri.base` keeps local-dev (localhost:3000) AND web
            // production (github.io/differentworld/) working from
            // the same code with no env-specific config.
            //
            // Mobile: deep-link back via the custom scheme declared
            // in android/app/src/main/AndroidManifest.xml +
            // ios/Runner/Info.plist.
            //
            // NOTE: every web origin used here MUST also be on the
            // Supabase project's Redirect URLs allowlist
            // (Dashboard → Authentication → URL Configuration).
            // Today: localhost:3000/** + jardinefaner.github.io/differentworld/**
            redirectTo: kIsWeb
                ? Uri.base.toString().split('?').first.split('#').first
                : 'com.jardine.differentworld://login-callback',
          );
      // signInWithOAuth returns immediately after launching the browser /
      // webview. The auth state change comes through later, the router
      // redirect takes us home.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The Horizon mark — the real brand logo (a gold sun
                  // rising over a horizon), squircle-clipped to the app-icon
                  // lockup. Flat, no shadow — on-brand with the calm
                  // direction. Replaces the placeholder "dw" gradient tile.
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: const HorizonMark(size: 96),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // The canonical wordmark widget (Jost, thin, tracked caps).
                  const Center(child: DwWordmark(size: 30)),
                  const SizedBox(height: 8),
                  Text(
                    'The classroom day, organized.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: _signingIn ? null : _signInWithGoogle,
                    icon: _signingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Continue with Google'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Guardian path is real (matched by email or invite
                  // code), but invisible from the staff login unless
                  // we surface it. Same button under the hood — the
                  // server matches the account to a guardian record
                  // and the router lands them on Family Today.
                  Text(
                    'Parent or guardian? Sign in with the email your\n'
                    "child's program has on file — same button above.",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
