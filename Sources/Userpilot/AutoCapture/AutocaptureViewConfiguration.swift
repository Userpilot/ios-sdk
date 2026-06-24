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

/// Internal type that owns autocapture view configuration: class defaults and
/// per-view responder setters (ignore-interactions, redaction). Stop/resume is no
/// longer here — it is per-instance state on each `AutoCaptureCoordinater`.
internal enum AutocaptureViewConfiguration {

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
