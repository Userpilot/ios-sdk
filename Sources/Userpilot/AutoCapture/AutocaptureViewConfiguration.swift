//
//  AutocaptureViewConfiguration.swift
//  Userpilot
//
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  Holds autocapture view configuration: class defaults for ignore-interactions
//  and ignore-inner-hierarchy, and setters that apply to responders. Keeps this
//  logic out of the main Userpilot entry class.
//

import ObjectiveC
import UIKit

/// Internal type that owns autocapture view configuration (class defaults, responder setters, stop/resume state).
internal enum AutocaptureViewConfiguration {

    // MARK: - Stop / Resume

    private static let stopResumeLock = NSLock()
    private static var _isAutoCaptureStopped = false

    /// When `true`, all autocapture paths exit at the first check (no screen or interaction events).
    static var isAutoCaptureStopped: Bool {
        _isAutoCaptureStopped
    }

    static func stopAutoCapture() {
        stopResumeLock.lock()
        _isAutoCaptureStopped = true
        stopResumeLock.unlock()
    }

    static func resumeAutoCapture() {
        stopResumeLock.lock()
        _isAutoCaptureStopped = false
        stopResumeLock.unlock()
    }

    // MARK: - Instance setters (called by Userpilot public API)

    static func setIgnoreInteractions(_ value: Bool, for responder: UIResponder) {
        responder.userpilotIgnoreInteractions = value
    }

    static func setIgnoreInnerHierarchy(_ value: Bool, for responder: UIResponder) {
        responder.userpilotIgnoreInnerHierarchy = value
    }

    static func setRedactText(_ value: Bool, for responder: UIResponder) {
        responder.userpilotRedactText = value
    }

    static func setRedactAccessibilityLabel(_ value: Bool, for responder: UIResponder) {
        responder.userpilotRedactAccessibilityLabel = value
    }

}
