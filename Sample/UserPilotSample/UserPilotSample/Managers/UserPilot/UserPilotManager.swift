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

    private var userPilot: UserPilot

    // MARK: - Life Cycle

    private init() {
        userPilot = UserPilot(config: UserPilot.Config(token: "NX-b7b285fd").logging(true))
    }

    func setup() {
        userPilot.initialize()
    }

    // MARK: - UserPilot SDK APIs

    func identify(userID: String) {
        userPilot.identify(userID: userID, properties: ["name": "Motasem", "age": 32])
    }

    func screen(_ name: String) {
        userPilot.screen(name)
    }

    // MARK: - Test Log multiEvents

    func startPerformanceTest() {
        userPilot.identify(userID: "4343")
        delay(3.0, closure: {
            self.userPilot.track(name: "Event 444")
            let count = 1...100
            for number in count {
                self.userPilot.track(name: "Event \(number)")
            }

//            self.userPilot.screen("Log in")
//            self.userPilot.identify(userID: "4343")
//            self.screen("Main screen 111")
//            self.userPilot.track(name: "Event New user \(999)")
//            self.screen("Main screen 222")
//            self.screen("Main screen 222")
//            self.screen("Main screen 333")
            delay(1) {
                for _ in 1...10 {
                    self.userPilot.track(name: "Event 100000")
                }

                self.userPilot.identify(userID: "1111")
                self.screen("Main screen 111")
                delay(2, closure: {
                    self.userPilot.track(name: "Event New user \(999)")
                })
                self.screen("Main screen 222")

                delay(2) {
                    self.screen("Main screen 222")
                    self.screen("Main screen 333")
                }
            }

        })

    }
}
