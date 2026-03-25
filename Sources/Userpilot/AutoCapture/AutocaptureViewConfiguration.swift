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

    // MARK: - Class-default storage

    private static let ignoreInteractionsDefaultLock = NSLock()
    private static var ignoreInteractionsDefaultByClass: [ObjectIdentifier: Bool] = [:]
    private static let ignoreInnerHierarchyDefaultLock = NSLock()
    private static var ignoreInnerHierarchyDefaultByClass: [ObjectIdentifier: Bool] = [:]

    // MARK: - Lookup (used by UIKitAutoCaptureProperties)

    /// Lookup class default for ignore interactions (walks superclass chain).
    static func ignoreInteractionsDefault(for type: AnyClass) -> Bool {
        var type: AnyClass? = type
        ignoreInteractionsDefaultLock.lock()
        defer { ignoreInteractionsDefaultLock.unlock() }
        while let cls = type {
            if let value = ignoreInteractionsDefaultByClass[ObjectIdentifier(cls)] {
                return value
            }
            type = class_getSuperclass(cls)
        }
        return false
    }

    /// Lookup class default for ignore inner hierarchy (walks superclass chain).
    static func ignoreInnerHierarchyDefault(for type: AnyClass) -> Bool {
        var type: AnyClass? = type
        ignoreInnerHierarchyDefaultLock.lock()
        defer { ignoreInnerHierarchyDefaultLock.unlock() }
        while let cls = type {
            if let value = ignoreInnerHierarchyDefaultByClass[ObjectIdentifier(cls)] {
                return value
            }
            type = class_getSuperclass(cls)
        }
        return false
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

    // MARK: - Class-default setters (called by Userpilot public API)

    static func setIgnoreInteractionsDefault(_ value: Bool, for responderType: UIResponder.Type) {
        ignoreInteractionsDefaultLock.lock()
        ignoreInteractionsDefaultByClass[ObjectIdentifier(responderType)] = value
        ignoreInteractionsDefaultLock.unlock()
    }

    static func setIgnoreInnerHierarchyDefault(_ value: Bool, for responderType: UIResponder.Type) {
        ignoreInnerHierarchyDefaultLock.lock()
        ignoreInnerHierarchyDefaultByClass[ObjectIdentifier(responderType)] = value
        ignoreInnerHierarchyDefaultLock.unlock()
    }
}
