//
//  AppFrameworkDetector.swift
//  Userpilot SDK
//
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Resolves the host app's UI framework (UIKit or SwiftUI) by inspecting
//  the key window's root view controller and writes the result back to
//  `Userpilot.Config.appFramework`.
//

import Foundation
import UIKit

/// Detects the host app's UI framework once a key window with a root view
/// controller becomes available.
///
/// The key window is rarely attached during
/// `application:didFinishLaunchingWithOptions:`, so this detector observes
/// scene/window notifications until detection succeeds. Once detected, the
/// observers are torn down immediately.
///
/// - Important: This class is only instantiated when the host app did **not**
///   set `Config.appFramework(_:)` explicitly. The caller (Userpilot's DI
///   setup) gates registration on `config.appFramework == nil`.
internal final class AppFrameworkDetector {

    // MARK: - Properties

    private let config: Userpilot.Config

    // MARK: - Initialization

    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
        start()
    }

    deinit {
        stopObserving()
    }

    // MARK: - Detection lifecycle

    /// Kicks off detection in three places, whichever fires first wins:
    /// 1. Next runloop tick (catches programmatic UIKit apps where the window
    ///    is already up by the time the SDK initializes).
    /// 2. `UIWindow.didBecomeKeyNotification` (catches storyboard apps).
    /// 3. `UIScene.didActivateNotification` (catches SwiftUI App lifecycle and
    ///    multi-scene apps).
    private func start() {
        DispatchQueue.main.async { [weak self] in
            self?.detectIfNeeded()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification),
            name: UIWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNotification),
            name: UIScene.didActivateNotification,
            object: nil
        )
    }

    @objc private func handleNotification() {
        detectIfNeeded()
    }

    /// Performs a single detection attempt. Stops observing as soon as the
    /// framework value is resolved (either by us or by the host app setting
    /// it explicitly while we were waiting).
    private func detectIfNeeded() {
        guard config.appFramework == nil else {
            stopObserving()
            return
        }

        guard let detected = Self.detect() else { return }

        config.appFramework = detected
        stopObserving()

        config.logger.info(
            "🔎 Userpilot auto-detected app framework: %{public}@",
            detected.rawValue
        )
    }

    private func stopObserving() {
        NotificationCenter.default.removeObserver(
            self, name: UIWindow.didBecomeKeyNotification, object: nil
        )
        NotificationCenter.default.removeObserver(
            self, name: UIScene.didActivateNotification, object: nil
        )
    }

    // MARK: - One-shot detection

    /// Inspects the current key window's root view controller to infer whether
    /// the host app is built with SwiftUI (root wrapped in `UIHostingController`)
    /// or UIKit. Returns `nil` if no key window/root VC is available yet.
    static func detect() -> Userpilot.AppFramework? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        let activeWindow = scenes
            .first(where: { $0.activationState == .foregroundActive })?
            .windows.first(where: { $0.isKeyWindow })

        let anyKeyWindow = scenes.first?.windows.first(where: { $0.isKeyWindow })

        guard let root = (activeWindow ?? anyKeyWindow)?.rootViewController else {
            return nil
        }

        let className = String(describing: type(of: root))
        return className.contains("UIHostingController") ? .SwiftUI : .UIKit
    }
}
