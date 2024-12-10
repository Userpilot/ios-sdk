//
//  AutoPropertyDecorator.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `AutoPropertyDecorator` class provides automatic property decoration for analytics events,
//  including system and app properties.
//  It conforms to the `AutoPropertyDecoratoring` protocol and implements the `AnalyticsDecorating`
//  protocol to modify event properties.
//

import Foundation
import UIKit

/**
 The `AutoPropertyDecoratoring` protocol defines methods for adding automatic properties to
 events and application-related properties.
 */
internal protocol AutoPropertyDecoratoring: AnyObject {
    /// Dictionary of automatic properties related to the system and device.
    var autoProperties: [String: Any] { get }

    /// Dictionary of properties related to the application.
    var appProperties: [String: Any] { get }
}

/**
 The `AutoPropertyDecorator` class implements the `AutoPropertyDecoratoring` protocol to provide
 automatic property decoration for analytics events. It includes system information, app
 properties, and font details.
 */
internal class AutoPropertyDecorator {

    // MARK: - Properties

    /// Configuration object for Userpilot.
    private let config: Userpilot.Config

    // MARK: - Initialization

    /**
     Initializes the `AutoPropertyDecorator` with the dependency injection container.
     
     - Parameter container: The dependency injection container holding references to required services.
     */
    init(container: DIContainer) {
        self.config = container.resolve(Userpilot.Config.self)
    }

    // MARK: - Auto Properties

    /// Provides system and device properties.
    private lazy var userpilotAutoProperties: [String: Any] = [
        AutoPropertyDecorator.osKey: "iOS",
        AutoPropertyDecorator.osVersionKey: UIDevice.current.systemVersion,
        AutoPropertyDecorator.appVersionKey: Bundle.main.version,
        AutoPropertyDecorator.deviceTypeKey: UIDevice.current.modelName,
        AutoPropertyDecorator.screenWidthKey: Int(UIScreen.main.bounds.size.width),
        AutoPropertyDecorator.screenHeightKey: Int(UIScreen.main.bounds.size.height)
    ]

    /// Provides application properties.
    private lazy var userpilotAppProperties: [String: Any] = [
        AutoPropertyDecorator.appNameKey: Bundle.main.displayName,
        AutoPropertyDecorator.appIdentifierKey: Bundle.main.identifier
    ]

}

// MARK: - AnalyticsDecorating

extension AutoPropertyDecorator: AutoPropertyDecoratoring {

    var autoProperties: [String: Any] {
        return userpilotAutoProperties
    }

    var appProperties: [String: Any] {
        return userpilotAppProperties
    }
}

// MARK: - Properties name

internal extension AutoPropertyDecorator {

    // Static constants
    private static let autoPropertiesKey = "autoProperties"
    private static let fontsKey = "fontsProperties"
    private static let appPropertiesKey = "appProperties"

    private static let osKey = "operating_system"
    private static let osVersionKey = "operating_system_version"
    private static let appVersionKey = "app_version"
    private static let deviceTypeKey = "device_type"
    private static let screenWidthKey = "screen_width"
    private static let screenHeightKey = "screen_height"

    private static let appNameKey = "app_name"
    private static let appIdentifierKey = "app_identifier"
}

internal extension UIUserInterfaceIdiom {
    /**
     Provides a string representation of the user interface idiom for analytics purposes.
     
     - Returns: A string representing the user interface idiom.
     */
    var analyticsName: String {
        if self == .pad {
            return "tablet"
        }
        return "phone"
    }
}
