//
//  Bundle+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
//  [Brief Description]
//  `Bundle+Data` contains extensions with helper methods for the `Bundle` class.
//  These methods provide convenient access to various pieces of information from the app's bundle,
//  including identifiers, names, versions, and build numbers.
//
//  Extensions include:
//  - `identifier`: The bundle identifier of the app.
//  - `displayName`: The display name of the app, or the application name if not set.
//  - `version`: The short version string of the app.
//  - `build`: The build version of the app.
//  - `applicationName`: The name of the app as specified in the bundle.
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
