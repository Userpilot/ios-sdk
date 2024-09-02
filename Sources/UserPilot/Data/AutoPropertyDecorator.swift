//
//  AutoPropertyDecorator.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//

import Foundation
import UIKit

protocol AutoPropertyDecoratoring: AnyObject, AnalyticsDecorating {
    var autoProperties: [String: Any] { get }
    var appProperties: [String: Any] { get }
}

class AutoPropertyDecorator {

    // MARK: - Properties
    private let config: UserPilot.Config

    private let autoPropertiesKey = "autoProperties"
    private let fontsKey = "fontsProperties"
    private let appPropertiesKey = "appProperties"

    private let osKey = "operating_system"
    private let osVersionKey = "operating_system_version"
    private let appVersionKey = "app_version"
    private let deviceTypeKey = "device_type"
    private let screenWidthKey = "screen_width"
    private let screenHeightKey = "screen_height"

    private let appNameKey = "app_name"
    private let appIdentifierKey = "app_identifier"

    private let appFontsKey = "appFonts"
    private let systemFontsKey = "systemFonts"

    // MARK: - init
    init(container: DIContainer) {
        self.config = container.resolve(UserPilot.Config.self)
    }

    // MARK: - Auto properties
    private lazy var userPilotAutoProperties: [String: Any] = [
        osKey: "iOS",
        osVersionKey: UIDevice.current.systemVersion,
        appVersionKey: Bundle.main.version,
        deviceTypeKey: UIDevice.deviceType,
        screenWidthKey: Int(UIScreen.main.bounds.size.width),
        screenHeightKey: Int(UIScreen.main.bounds.size.height)
    ]

    private lazy var userPilotAppProperties: [String: Any] = [
        appNameKey: Bundle.main.displayName,
        appIdentifierKey: Bundle.main.identifier
    ]

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
            (appFontsKey, appFonts),
            (systemFontsKey, systemFonts)
        ]
    }()

//    internal var autoProperties: [String: Any] {
//        let properties = config.additionalAutoProperties
//            .merging(userPilotDefaultProperties)
//        return properties
//    }

}

// MARK: - AnalyticsDecorating
extension AutoPropertyDecorator: AutoPropertyDecoratoring {
    var autoProperties: [String: Any] {
        return userPilotAutoProperties
    }

    var appProperties: [String: Any] {
        return userPilotAppProperties
    }

    func decorate(_ event: Event) -> Event {
        return event
//        var decoratedEvent = event
//        decoratedEvent.properties?[autoPropertiesKey] = autoProperties
//        if event.type.isIdentifyEvent {
//            decoratedEvent.properties?[appPropertiesKey] = userPilotClientAppProperties
//            // decorated.properties?[fontsKey] = fonts
//        }
//        return decoratedEvent
    }

}

extension UIUserInterfaceIdiom {
    var analyticsName: String {
        if self == .pad {
            return "tablet"
        }
        return "phone"
    }
}
