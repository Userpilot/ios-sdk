//
//  UserPilotManager.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 18/08/2024.
//

import Foundation
import UserPilot

class UserPilotManager {

    // MARK: - Public Properties
    static let shared = UserPilotManager()

    // MARK: - Private Properties
    private let userPilot = UserPilot(config: UserPilot.Config(token: "NX-b7b285fd").logging(true))

    // MARK: - Life Cycle
    private init() { }

    // MARK: - UserPilot SDK APIs
    func identify(userID: String) {
        userPilot.identify(userID: userID, properties: ["name": "Motasem", "age": 32])
    }

    func screen(_ name: String, properties: [String: Any]? = nil) {
        userPilot.screen(name, properties: properties)
    }
}
