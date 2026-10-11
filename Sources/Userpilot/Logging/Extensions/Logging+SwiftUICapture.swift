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
#endif

internal extension Logging {
    /// Keeps the scan prefix/timing while respecting Config.logging and SDK instance attribution.
    /// The message is an argument, so percent signs are never format directives.
    /// DEBUG diagnostics include full captured text; analytics payloads retain their privacy rules.
    /// Release builds do not evaluate the message. A nil message skips a conditional diagnostic.
    func debugSwiftUICapture(_ message: @autoclosure () -> String?) {
        #if DEBUG
        guard let message = message() else { return }
        let elapsedMilliseconds = (CFAbsoluteTimeGetCurrent() - swiftUICaptureLogStart) * 1000
        debug("[UP-SUI] +%9.1fms  %{public}@", elapsedMilliseconds, message)
        #endif
    }

    /// Log complete titles with the existing labels, counts and chunk boundaries in DEBUG builds only.
    func debugSwiftUITitles(_ label: String, _ titles: @autoclosure () -> [String], chunkSize: Int = 8) {
        #if DEBUG
        let titles = titles()
        guard !titles.isEmpty else {
            debugSwiftUICapture("  → \(label)(0): []")
            return
        }
        for start in stride(from: 0, to: titles.count, by: chunkSize) {
            let end = min(start + chunkSize, titles.count)
            let chunk = Array(titles[start..<end])
            debugSwiftUICapture("  → \(label)(\(titles.count))[\(start)..<\(end)]: \(chunk)")
        }
        #endif
    }
}
