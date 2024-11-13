//
//  EnvironmentManager.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 13/11/2024.
//

import Foundation

class EnvironmentManager {

    static let shared = EnvironmentManager()

    private init() {}

    func isEnternalTestVersion() -> Bool {
        if let isInternalRelease = readConfigValue(forKey: "IS_INTERNAL_RELEASE") as? String,
           isInternalRelease == "true" {
            return true
        } else {
            return false
        }
    }

}
