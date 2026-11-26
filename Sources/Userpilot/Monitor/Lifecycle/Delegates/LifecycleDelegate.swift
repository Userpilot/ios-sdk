//
//  LifecycleDelegate.swift
//  Userpilot SDK
//
//  Created by Userpilot on 18/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Native lifecycle notifications consumed by SDK features on main.
//

import UIKit

/// Weak subscribers implement only the native events their feature needs.
internal protocol LifecycleDelegate: AnyObject {
    func onAppActive()
    func onAppBackground()
    func onSceneActive()
    func onSceneDisconnected(_ scene: UIScene)
    func onWindowBecameKey()
    func onMemoryWarning()
}

extension LifecycleDelegate {
    func onAppActive() {}
    func onAppBackground() {}
    func onSceneActive() {}
    func onSceneDisconnected(_ scene: UIScene) {}
    func onWindowBecameKey() {}
    func onMemoryWarning() {}
}
