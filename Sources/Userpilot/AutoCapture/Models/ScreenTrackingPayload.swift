//
//  ScreenTrackingPayload.swift
//  Userpilot SDK
//
//  Created by Userpilot on 28/03/2026.
//  Copyright © 2026 Userpilot. All rights reserved.
//
//  Describes a captured screen and its controller, title and container metadata.
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
}

// MARK: - Event dictionaries

extension ScreenTrackingPayload {
    /// Screen properties keep optional values when present, including an empty navigation title.
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
        return dict
    }

    /// Native interaction context omits an empty navigation title and excludes screen-only metadata.
    func toEventDictionary() -> [String: String] {
        var screen = [
            Constants.AutoCapture.screenTitle: screenClass,
            Constants.AutoCapture.screenName: currentScreen
        ]
        if let navigationTitle, !navigationTitle.isEmpty {
            screen[Constants.AutoCapture.navigationTitle] = navigationTitle
        }
        return screen
    }

    /// Wrapper interactions provide their own hierarchy and use only the tracked class as title.
    func toWrapperEventDictionary() -> [String: String] {
        [Constants.AutoCapture.screenTitle: screenClass]
    }
}

// MARK: - Capture identity and hierarchy

extension ScreenTrackingPayload {
    /// UIKit keeps controller identity; SwiftUI uses its resolved logical name when present.
    func screenEventIdentity(framework: Userpilot.AppFramework?) -> String {
        guard framework == .SwiftUI else { return screenClass }
        let logicalName = currentScreen.trimmingCharacters(in: .whitespacesAndNewlines)
        return logicalName.isEmpty ? screenClass : logicalName
    }

    /// Diagnostic comparison for SwiftUI destinations that inherit a previous navigation title.
    func matchesPreviousScreen(_ previousScreen: ScreenTrackingPayload?, framework: Userpilot.AppFramework?) -> Bool {
        guard framework == .SwiftUI, let previousScreen else { return false }
        let currentScreen = self.currentScreen.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !currentScreen.isEmpty else { return false }

        let previousValues = [
            previousScreen.currentScreen,
            previousScreen.navigationTitle
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        return previousValues.contains(currentScreen)
    }

    /// Replaces an unresolved owning controller using the original, untrimmed screen class.
    func replaceUnknownScreenPlaceholder(in hierarchy: String) -> String {
        let placeholder = Constants.AutoCapture.unknownScreenHierarchyPlaceholder
        guard hierarchy.contains(placeholder), !screenClass.isEmpty else { return hierarchy }
        return hierarchy.replacingOccurrences(of: placeholder, with: screenClass)
    }

    /// Appends the escaped screen class only when both the supplied hierarchy and class are nonempty.
    func buildHierarchyPath(_ hierarchy: String) -> String {
        guard !hierarchy.isEmpty else { return hierarchy }
        let screenClass = self.screenClass.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !screenClass.isEmpty else { return hierarchy }
        let escaped = screenClass.replacingOccurrences(of: "\"", with: "\\\"")
        return hierarchy + ";\(escaped)"
    }
}

// MARK: - Manual screen tracking

extension ScreenTrackingPayload {
    init(screenTitle: String, appFramework: Userpilot.AppFramework? = nil) {
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
    }
}
