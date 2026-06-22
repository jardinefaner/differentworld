package com.jardine.differentworld

import android.app.ActivityManager
import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Channel name MUST match `lib/features/kid_mode/screen_pinning.dart`.
    private val screenPinningChannel = "com.jardine.differentworld/screen_pinning"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Privacy posture: hide sensitive UI (children's data, photos,
        // observation narratives) from the task-switcher snapshot and
        // from screenshots / screen-recording. Release builds only —
        // debug builds need screenshots for QA + bug-report dogfooding.
        // CLAUDE.md "Background screenshots" gotcha calls for this.
        //
        // We detect debug via the manifest's FLAG_DEBUGGABLE rather
        // than BuildConfig.DEBUG because AGP 8+ disables BuildConfig
        // generation by default, and enabling it just for one boolean
        // check isn't worth the build-time cost.
        val isDebuggable =
            (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        if (!isDebuggable) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE,
            )
        }
    }

    // Screen pinning (lock-task) for the kid photo-turns session. The Dart
    // side (ScreenPinning) calls "startLockTask" when the "Whose turn?"
    // picker opens and "stopLockTask" when it closes, so a kid handed the
    // phone for their five minutes physically can't swipe out to another app.
    //
    // NOTE: we are a NORMAL app, not a device-owner / lock-task-allowlisted
    // app. For a non-device-owner app, `startLockTask()` enters the OS
    // "screen-pinning" mode, which on the FIRST use shows the system
    // "Pin this app? … hold Back + Overview to unpin" confirmation dialog.
    // That dialog is EXPECTED, not a bug — it's the only screen-pinning path
    // available without enterprise device-owner provisioning, and it's why we
    // never surface a `result.error` for it (that would crash the Dart call
    // and break the turn flow). We answer success(false) on the security /
    // state exceptions and let the turn proceed with the in-app kid-lock
    // (kidMode + the 5-tap reclaim) as the always-present fallback layer.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            screenPinningChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLockTask" -> {
                    // Must run on the UI thread — startLockTask() touches the
                    // Activity's window. Answer success(true/false), never
                    // error, so the Dart caller never throws.
                    runOnUiThread {
                        try {
                            startLockTask()
                            result.success(true)
                        } catch (e: SecurityException) {
                            result.success(false)
                        } catch (e: IllegalStateException) {
                            result.success(false)
                        }
                    }
                }
                "stopLockTask" -> {
                    runOnUiThread {
                        try {
                            stopLockTask()
                        } catch (ignored: Exception) {
                            // Already unpinned / never pinned — idempotent.
                        }
                        result.success(true)
                    }
                }
                "isLockTaskActive" -> {
                    val am =
                        getSystemService(ACTIVITY_SERVICE) as ActivityManager
                    result.success(
                        am.lockTaskModeState !=
                            ActivityManager.LOCK_TASK_MODE_NONE,
                    )
                }
                else -> result.notImplemented()
            }
        }
    }
}
