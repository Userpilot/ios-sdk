//
//  ScreenTrackingPayload.swift
//  Userpilot
//
//  Created by Motasem Hamed on 28/03/2026.
//

import Foundation

/// Payload containing comprehensive screen tracking information for auto capture events.
internal struct ScreenTrackingPayload: Equatable {
    // MARK: - Properties

    /// The current screen name
    let currentScreen: String

    /// The class name of the current screen's view controller
    let screenClass: String

    /// The type of screen (e.g., "ViewController", "NavigationController")
    let screenType: String

    /// The navigation title of the screen
    let navigationTitle: String?

    /// Whether this view controller is a Userpilot container class
    let isUserpilotContainerClass: Bool

    /// The accessibilityIdentifier of the view controller
    let vcAccessibilityIdentifier: String?

    /// The accessibilityLabel of the view controller
    let vcAccessibilityLabel: String?

    /// True when SwiftUI resolved this screen to the same name/title as the previous screen context.
    var screenNameMatchesPreviousScreen: Bool?

    /// True when this payload represents a `UIAlertController`
    /// (including subclasses) — dialog autocapture instead of a screen event.
    var isDialogPresentation: Bool = false

    /// Alert title from `UIAlertController.title` when `isDialogPresentation` is true.
    var alertTitle: String?

    /// Alert message from `UIAlertController.message`.
    var alertMessage: String?

    /// The app framework reported by the owning Userpilot instance at the time the
    /// payload was built. Stored on the payload so screen events route the correct
    /// per-tenant `ui_framework` value rather than reading from the SDK default
    /// fallback, which is wrong when multiple instances coexist.
    var appFramework: Userpilot.AppFramework?

    /// Live navigation stack and container ancestry, captured separately at screen appearance.
    var screenHierarchy: [String]?
    var screenContainerHierarchy: [String]?

    // MARK: - Conversion

    /// Converts the payload to a dictionary for event properties
    /// - Returns: Dictionary representation of the payload
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            Constants.AutoCapture.screenName: currentScreen,
            Constants.AutoCapture.screenClass: screenClass,
            Constants.AutoCapture.screenType: screenType,
            Constants.AutoCapture.isUserpilotContainerClass: isUserpilotContainerClass,
            Constants.AutoCapture.source: Constants.AutoCapture.autoCaptureSourceValue
        ]

        if let navigationTitle = navigationTitle {
            dict[Constants.AutoCapture.navigationTitle] = navigationTitle
        }

        if let vcAccessibilityIdentifier = vcAccessibilityIdentifier {
            dict[Constants.AutoCapture.vcAccessibilityIdentifier] = vcAccessibilityIdentifier
        }

        if let vcAccessibilityLabel = vcAccessibilityLabel {
            dict[Constants.AutoCapture.vcAccessibilityLabel] = vcAccessibilityLabel
        }

        if let screenNameMatchesPreviousScreen {
            dict[Constants.AutoCapture.screenNameMatchesPreviousScreen] = screenNameMatchesPreviousScreen
        }

        if let appFramework = appFramework {
            dict[Constants.AutoCapture.uiFramework] = appFramework.rawValue
        }
        if let screenHierarchy, !screenHierarchy.isEmpty {
            dict[Constants.AutoCapture.screenHierarchy] = screenHierarchy
        }
        if let screenContainerHierarchy, !screenContainerHierarchy.isEmpty {
            dict[Constants.AutoCapture.screenContainerHierarchy] = screenContainerHierarchy
        }
        return dict
    }
}

// MARK: - Manual screen tracking

extension ScreenTrackingPayload {
    init(
        screenTitle: String,
        appFramework: Userpilot.AppFramework? = nil,
        screenHierarchy: [String]? = nil
    ) {
        self.init(
            currentScreen: screenTitle,
            screenClass: screenTitle,
            screenType: "",
            navigationTitle: nil,
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: nil,
            vcAccessibilityLabel: nil
        )
        self.appFramework = appFramework
        if let screenHierarchy, !screenHierarchy.isEmpty, screenHierarchy.count <= 64,
           screenHierarchy.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            self.screenHierarchy = screenHierarchy
        }
    }
}

// MARK: - Wrapper screens

extension ScreenTrackingPayload {
    func toWrapperScreenProperties() -> [String: Any] {
        var properties: [String: Any] = [Constants.AutoCapture.source: Constants.AutoCapture.autoCaptureSourceValue]
        if let screenHierarchy {
            properties[Constants.AutoCapture.screenHierarchy] = screenHierarchy
        }
        return properties
    }
}
