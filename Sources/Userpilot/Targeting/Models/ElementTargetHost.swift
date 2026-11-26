//
//  ElementTargetHost.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Weak native identity retained by one targeting or Builder capture operation.
//

import UIKit

/// All references are main-thread-only. A host never keeps an app window or SDK owner alive.
internal final class ElementTargetHost {
    private(set) weak var window: UIWindow?
    private(set) weak var rootViewController: UIViewController?
    private(set) weak var scene: UIWindowScene?
    private(set) weak var owner: Userpilot?
    let hadScene: Bool
    let wasSceneConnected: Bool
    let rootViewControllerID: ObjectIdentifier?
    /// The view that last proved `owner` owns part of this window. Rechecked before every reuse.
    weak var ownedView: UIView?

    init(window: UIWindow, owner: Userpilot) {
        self.window = window
        rootViewController = window.rootViewController
        rootViewControllerID = window.rootViewController.map(ObjectIdentifier.init)
        scene = window.windowScene
        hadScene = window.windowScene != nil
        // UIKit can provide a legacy window scene outside connectedScenes. Record membership
        // at admission so later validation detects disconnects without rejecting legacy hosts.
        wasSceneConnected = window.windowScene.map { UIApplication.shared.connectedScenes.contains($0) } ?? false
        self.owner = owner
    }
}
