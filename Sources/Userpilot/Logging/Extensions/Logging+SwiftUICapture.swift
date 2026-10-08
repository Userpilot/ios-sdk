//
//  Logging+SwiftUICapture.swift
//  Userpilot SDK
//
//  Created by Userpilot on 08/10/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Formats native scan diagnostics through the owning instance's existing SDK logger.
//

import Foundation

#if DEBUG
private let swiftUICaptureLogStart = CFAbsoluteTimeGetCurrent()

internal extension Logging {
    /// Keeps the scan prefix/timing while respecting Config.logging and SDK instance attribution.
    /// The message is an argument, so percent signs in captured titles are never format directives.
    func debugSwiftUICapture(_ message: @autoclosure () -> String) {
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - swiftUICaptureLogStart) * 1000
        debug("[UP-SUI] +%9.1fms  %{public}@", elapsedMilliseconds, message())
    }
}
#endif
