package com.jardine.differentworld

import android.content.pm.ApplicationInfo
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
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
}
