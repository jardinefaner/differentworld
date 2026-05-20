import Flutter
import UIKit

/// Privacy posture for the iOS app-switcher snapshot.
///
/// Before iOS captures its snapshot of the app (which happens as we
/// transition to inactive — covered by `sceneWillResignActive`), we
/// drop a solid-coloured cover view on top of the window so the
/// preview the OS stores in the task switcher doesn't leak the
/// children's data on screen. We remove the cover in
/// `sceneDidBecomeActive` once the user returns.
///
/// Debug builds skip the cover so QA + dogfooding builds can capture
/// task-switcher screenshots normally. Mirrors the Android side
/// (`MainActivity` sets `FLAG_SECURE` in release).
class SceneDelegate: FlutterSceneDelegate {
    private var privacyCover: UIView?

    override func sceneWillResignActive(_ scene: UIScene) {
        super.sceneWillResignActive(scene)
        #if !DEBUG
        installPrivacyCover()
        #endif
    }

    override func sceneDidBecomeActive(_ scene: UIScene) {
        super.sceneDidBecomeActive(scene)
        removePrivacyCover()
    }

    private func installPrivacyCover() {
        guard
            let window = (window),
            privacyCover == nil
        else { return }
        let cover = UIView(frame: window.bounds)
        // Match the launch storyboard's background so the snapshot
        // reads as "app is loading," not as a broken / empty screen.
        cover.backgroundColor = UIColor.systemBackground
        cover.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(cover)
        privacyCover = cover
    }

    private func removePrivacyCover() {
        privacyCover?.removeFromSuperview()
        privacyCover = nil
    }
}
