//
//  Bundle+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `Bundle+Extension` contains extensions with helper methods for the `Bundle` class.
//  These methods provide convenient access to various pieces of information from the app's bundle,
//  including identifiers, names, versions, and build numbers.
//

import Foundation

internal extension Bundle {

    var identifier: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleIdentifier") as? String ?? ""
    }

    var displayName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? applicationName
    }

    var version: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var build: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    var applicationName: String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
    }

}

internal extension Userpilot {
    static let resourceBundle: Bundle = {
#if SWIFT_PACKAGE
        // Swift Package Manager (SPM) case
        return Bundle.module
#else
        // CocoaPods case
        if let url = Bundle(for: Userpilot.self).url(forResource: "Userpilot", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        } else if let url = Bundle(for: Userpilot.self).url(forResource: "UserPilot", withExtension: "bundle"),
            let bundle = Bundle(url: url) {
            return bundle
        } else {
#if DEBUG
            fatalError("Can't find 'Userpilot' resource bundle")
#endif
        }
#endif
    }()
}
