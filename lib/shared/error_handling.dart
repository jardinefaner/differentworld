import 'package:flutter/material.dart';

/// Run `action` and route any `Exception` it throws through Flutter's
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
/// Default visible duration for a SUCCESS snackbar. Short — the user
/// already initiated the action and just needs a brief confirmation.
/// Override per call when the message needs more reading time.
const Duration kSnackSuccessDuration = Duration(seconds: 2);

/// Default visible duration for an ERROR snackbar. Long — error copy
/// is usually longer and the user may need to read it twice. Six
/// seconds matches the M3 spec's "snackbar with action" recommendation
/// (4-10s); we pick the high end because errors deserve attention.
const Duration kSnackErrorDuration = Duration(seconds: 6);

Future<bool> runReported({
  required String library,
  required Future<void> Function() action,
  ScaffoldMessengerState? messenger,
  String? onError,
  String? onSuccess,
  Duration successDuration = kSnackSuccessDuration,
  Duration errorDuration = kSnackErrorDuration,
}) async {
  try {
    await action();
    if (onSuccess != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(onSuccess), duration: successDuration),
      );
    }
    return true;
  } on Exception catch (e, st) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: e, stack: st, library: library),
    );
    if (onError != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(onError), duration: errorDuration),
      );
    }
    return false;
  }
}
