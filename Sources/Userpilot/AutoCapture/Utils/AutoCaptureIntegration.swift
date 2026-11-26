//
//  AutoCaptureIntegration.swift
//  Userpilot SDK
//
//  Created by Userpilot on 11/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Coordinates native capture effects that cross SDK instance boundaries.
//

import Foundation

/// Capture effects shared by every instance observing the same application UI.
internal protocol AutoCaptureIntegrating: AnyObject {
    func suppressScreenAutoCaptureAfterSDKContent()
}

/// SDK dismissal can reappear screens belonging to another instance. Suppress each
/// active screen tracker without changing which instance owns the underlying UI.
internal final class AutoCaptureIntegration: AutoCaptureIntegrating {
    private let registry: InstanceRegistering

    init(registry: InstanceRegistering) {
        self.registry = registry
    }

    func suppressScreenAutoCaptureAfterSDKContent() {
        for instance in registry.allInstances where instance.config.enableScreenAutoCapture {
            instance.autoCaptureCoordinator.suppressScreenAutoCaptureAfterSDKContent()
        }
    }
}
