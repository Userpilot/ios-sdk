//
//  CaptureUploadBackgroundTask.swift
//  Userpilot SDK
//
//  Created by Userpilot on 29/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Requests background execution time for one capture upload run, retries included.
//

import UIKit

/// Background time for one upload run. Main-confined; replaceable in tests.
internal protocol CaptureUploadBackgroundTasking: AnyObject {
    /// Ends any earlier task first. `onExpiration` runs on main when the system runs out of time.
    func begin(onExpiration: @escaping () -> Void)
    /// Idempotent.
    func end()
}

/// Lets a run started in the foreground finish if the operator leaves the app anyway.
/// `end()` is idempotent and deinit releases a task that was never ended.
internal final class CaptureUploadBackgroundTask: CaptureUploadBackgroundTasking {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    func begin(onExpiration: @escaping () -> Void) {
        end()
        identifier = UIApplication.shared.beginBackgroundTask(
            withName: Constants.BuilderCapture.Upload.backgroundTaskName
        ) { [weak self] in
            guard let self, self.identifier != .invalid else { return }
            onExpiration()
            self.end()
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }

    deinit {
        guard identifier != .invalid else { return }
        let identifier = identifier
        performOnMain { UIApplication.shared.endBackgroundTask(identifier) }
    }
}
