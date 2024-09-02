//
//  Bundle+Data.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// Bundle+Data contains extensions helper methods
//

import Foundation

extension Bundle {

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
