import 'package:flutter/material.dart';

/// Run [action] and route any [Exception] it throws through Flutter's
/// error reporter, then optionally surface a snackbar.
///
/// Replaces the ~17 hand-rolled blocks of:
///
///     try {
///       await someAction();
///       messenger?.showSnackBar(...success...);
///     } on Exception catch (e, st) {
///       FlutterError.reportError(
///         FlutterErrorDetails(exception: e, stack: st, library: 'foo'),
///       );
///       messenger?.showSnackBar(...error...);
///     }
///
/// …with one consistent shape:
///
///     await runReported(
///       library: 'foo',
///       messenger: messenger,                 // optional
///       onError:   'Could not save the foo.', // optional snackbar
///       onSuccess: 'Saved.',                   // optional snackbar
///       action:    () => actions.save(...),
///     );
///
/// `messenger` is captured by the caller BEFORE any await (per the
/// `mounted-after-await` skill) so it remains valid even if the
/// originating widget unmounts mid-action.
///
/// Errors propagate through `FlutterError.reportError`, which the
/// app's global handler routes to Sentry / logging when those land.
/// Until then it goes to the debug console — same as the inline form.
///
/// Returns `true` when the action completed without an Exception,
/// `false` otherwise. Most callers ignore the result; flows that
/// need to "do this and then navigate only on success" branch on it.
Future<bool> runReported({
  required String library,
  required Future<void> Function() action,
  ScaffoldMessengerState? messenger,
  String? onError,
  String? onSuccess,
}) async {
  try {
    await action();
    if (onSuccess != null) {
      messenger?.showSnackBar(SnackBar(content: Text(onSuccess)));
    }
    return true;
  } on Exception catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: library),
    );
    if (onError != null) {
      messenger?.showSnackBar(SnackBar(content: Text(onError)));
    }
    return false;
  }
}
