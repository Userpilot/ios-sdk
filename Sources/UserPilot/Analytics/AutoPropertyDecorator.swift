//
//  AutoPropertyDecorator.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
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
 
 - Properties:
   - `autoProperties`: Dictionary of automatic properties related to the system and device.
   - `appProperties`: Dictionary of properties related to the application.
 
 - Methods:
   - `decorate(_:)`: Method to decorate events with additional properties.
 */
internal protocol AutoPropertyDecoratoring: AnyObject, AnalyticsDecorating {
    var autoProperties: [String: Any] { get }
    var appProperties: [String: Any] { get }
}

/**
 The `AutoPropertyDecorator` class implements the `AutoPropertyDecoratoring` protocol to provide
 automatic property decoration for analytics events. It includes system information, app
 properties, and font details.
 */
internal class AutoPropertyDecorator {

    // MARK: - Properties

    /// Configuration object for UserPilot.
    private let config: UserPilot.Config

    // MARK: - Initialization

    /**
     Initializes the `AutoPropertyDecorator` with the dependency injection container.
     
     - Parameter container: The dependency injection container holding references to required services.
     */
    init(container: DIContainer) {
        self.config = container.resolve(UserPilot.Config.self)
    }

    // MARK: - Auto Properties

    /// Provides system and device properties.
    private lazy var userPilotAutoProperties: [String: Any] = [
        AutoPropertyDecorator.osKey: "iOS",
        AutoPropertyDecorator.osVersionKey: UIDevice.current.systemVersion,
        AutoPropertyDecorator.appVersionKey: Bundle.main.version,
        AutoPropertyDecorator.deviceTypeKey: UIDevice.deviceType,
        AutoPropertyDecorator.screenWidthKey: Int(UIScreen.main.bounds.size.width),
        AutoPropertyDecorator.screenHeightKey: Int(UIScreen.main.bounds.size.height)
    ]

    /// Provides application properties.
    private lazy var userPilotAppProperties: [String: Any] = [
        AutoPropertyDecorator.appNameKey: Bundle.main.displayName,
        AutoPropertyDecorator.appIdentifierKey: Bundle.main.identifier
    ]

    /// Provides information about app and system fonts.
    private lazy var fonts: [(title: String, names: [String])] = {
        let familyNames: [String] = (Bundle.main.infoDictionary?["UIAppFonts"] as? [String] ?? [])
            .compactMap { resourceName in
                if let url = Bundle.main.url(forResource: resourceName, withExtension: nil),
                   let fontData = try? Data(contentsOf: url),
                   let fontDataProvider = CGDataProvider(data: fontData as CFData),
                   let font = CGFont(fontDataProvider),
                   let name = font.postScriptName {
                    let ctfont = CTFontCreateWithName(name, 17, nil)
                    return CTFontCopyFamilyName(ctfont) as String
                } else {
                    return nil
                }
            }

        let appFonts = Set(familyNames).sorted().flatMap { UIFont.fontNames(forFamilyName: $0) }
        let systemFonts = UIFontDescriptor.SystemDesign.allCases.flatMap { design in
            UIFont.Weight.allCases.map { weight in
                "System \(design.description) \(weight.description)"
            }
        }

        return [
            (AutoPropertyDecorator.appFontsKey, appFonts),
            (AutoPropertyDecorator.systemFontsKey, systemFonts)
        ]
    }()

}

// MARK: - AnalyticsDecorating

extension AutoPropertyDecorator: AutoPropertyDecoratoring {

    var autoProperties: [String: Any] {
        return userPilotAutoProperties
    }

    var appProperties: [String: Any] {
        return userPilotAppProperties
    }

    /**
     Decorates the provided event with additional properties related to the system, application, and fonts.
     
     - Parameter event: The event to decorate.
     - Returns: A new event with additional properties.
     */
    func decorate(_ event: Event) -> Event {
        var decoratedEvent = event
        decoratedEvent.properties?[AutoPropertyDecorator.autoPropertiesKey] = autoProperties
        if event.type.isIdentifyEvent {
            decoratedEvent.properties?[AutoPropertyDecorator.appPropertiesKey] = appProperties
            decoratedEvent.properties?[AutoPropertyDecorator.fontsKey] = fonts
        }
        return decoratedEvent
    }
}

// MARK: - Properties name

internal extension AutoPropertyDecorator {

    // Static constants
    static var autoPropertiesKey: String { return "autoProperties" }
    static var fontsKey: String { return "fontsProperties" }
    static var appPropertiesKey: String { return "appProperties" }

    static var osKey: String { return "operating_system" }
    static var osVersionKey: String { return "operating_system_version" }
    static var appVersionKey: String { return "app_version" }
    static var deviceTypeKey: String { return "device_type" }
    static var screenWidthKey: String { return "screen_width" }
    static var screenHeightKey: String { return "screen_height" }

    static var appNameKey: String { return "app_name" }
    static var appIdentifierKey: String { return "app_identifier" }

    static var appFontsKey: String { return "appFonts" }
    static var systemFontsKey: String { return "systemFonts" }
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
