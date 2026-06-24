//
//  ScreenTrackingPayload.swift
//  Userpilot
//
//  Created by Motasem Hamed on 28/03/2026.
//

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

    // MARK: - Conversion

    /// Converts the payload to a dictionary for event properties
    /// - Returns: Dictionary representation of the payload
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            AutoCaptureConstants.screenName: currentScreen,
            AutoCaptureConstants.screenClass: screenClass,
            AutoCaptureConstants.screenType: screenType,
            AutoCaptureConstants.isUserpilotContainerClass: isUserpilotContainerClass,
            AutoCaptureConstants.source: AutoCaptureConstants.autoCaptureSourceValue
        ]

        if let navigationTitle = navigationTitle {
            dict[AutoCaptureConstants.navigationTitle] = navigationTitle
        }

        if let vcAccessibilityIdentifier = vcAccessibilityIdentifier {
            dict[AutoCaptureConstants.vcAccessibilityIdentifier] = vcAccessibilityIdentifier
        }

        if let vcAccessibilityLabel = vcAccessibilityLabel {
            dict[AutoCaptureConstants.vcAccessibilityLabel] = vcAccessibilityLabel
        }

        if let screenNameMatchesPreviousScreen {
            dict[AutoCaptureConstants.screenNameMatchesPreviousScreen] = screenNameMatchesPreviousScreen
        }

        if let appFramework = appFramework {
            dict[AutoCaptureConstants.uiFramework] = appFramework.rawValue
        }
        return dict
    }
}

// MARK: - Manual screen tracking

extension ScreenTrackingPayload {
    init(screenTitle: String, appFramework: Userpilot.AppFramework? = nil) {
        self.init(
            currentScreen: screenTitle,
            screenClass: screenTitle,
            screenType: "UIViewController",
            navigationTitle: nil,
            isUserpilotContainerClass: false,
            vcAccessibilityIdentifier: nil,
            vcAccessibilityLabel: nil
        )
        self.appFramework = appFramework
    }
}
