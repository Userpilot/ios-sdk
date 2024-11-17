//
//  UserPilotManager.swift
//  UserPilotSample
//
//  Created by Motasem Hamed on 18/08/2024.
//

import Foundation
import UserPilot
import UIKit

class UserPilotManager {

    // MARK: - Public Properties

    static let shared = UserPilotManager()

    // MARK: - Private Properties

    private var userPilot: UserPilot?

    private(set) var userPilotSDKEvents = [UserPilotSDKEvents]()

    // MARK: - Life Cycle

    private init() { }

    // MARK: - UserPilot SDK APIs

    func initialize() {
        guard
            let appToken: String = StorageManager.shared.get(forKey: StorageManager.Keys.appToken)
        else { return }
        userPilot = UserPilot(config: UserPilot.Config(token: appToken)
            .logging(true)
            .setNavigationHandler(navigationDelegate: self)
            .setAnalyticsDelegate(analyticsDelegate: self)
        )
    }

    /// UserPilot Settings
    @discardableResult
    func settings() -> [String: Any] {
        return userPilot?.settings() ?? [:]
    }

    /// Identify user
    func identify(userID: String, properties: [String: Any]? = nil, company: [String: Any]? = nil) {
        userPilot?.identify(userID: userID, properties: properties, company: company)
    }

    /// login as Anonymous
    func anonymous() {
        userPilot?.anonymous()
    }

    /// Logout user
    func logout() {
        userPilot?.logout()
    }

    /// Track screens
    func screen(_ screenTitle: String) {
        userPilot?.screen(screenTitle)
    }

    /// Track user events
    func track(eventName: String, properties: [String: Any]? = nil) {
        userPilot?.track(eventName: eventName, properties: properties)
    }

    func triggerExperience(token: String) {
        userPilot?.triggerExperience(token)
    }

    // MARK: - Test Log multiEvents

    /**
    Call this method from any where to test app performance.
     
    - Test Cases to Cover
     1- Sequential User Identifications
        Description: Verify that multiple user identification requests are processed sequentially without
        any data overlap or race conditions.

     - Test Steps:
        Identify User NX-11111.
        Identify User NX-22222 immediately after.
     * Expected Outcome: Each user should be identified correctly in sequence, but the SDK will close
       the socket immediately for first user and cancel all its events and open new socket for new user.
     
     2- Multiple Different Events
        Description: Test that different types of events are tracked accurately without interference.

     - Test Steps:
        Automatic event 1
        Automatic event 1.
        Automatic event 1.
     * Expected Outcome: The system should successfully track all events, cache them, debounce them and
       then send them as a patch event.
     
     3- Repeated Same Event
        Description: Ensure that sending the same event multiple times is handled correctly, and all
     occurrences are tracked.

     - Test Steps:
        Track Event 100000.
        Track Event 100000 again.
        Track Event 100000 a third time, etc...
     * Expected Outcome: All instances of Event A should be tracked independently, and the SDK will take
       first event and drop the other events.
     
     3- Screen View Events
        Description: Test that screen view events are tracked properly, with accurate timestamps and no
        duplication when switching between screens.

     - Test Steps:
        Send a screen view event for Screen Main.
        Switch to Screen Profile and send the same screen again.
        Return to Screen Main.
     * Expected Outcome: Each screen view should be recorded with the correct screen name, with drop
       to duplicated screens.
     
     * Further Enhancements:
     - Edge Cases: You might want to consider edge cases like sending events while the app is in the
       background or sending invalid user information (e.g., missing user ID) to ensure the robustness of the system.

     - Concurrency: Add a case where multiple events are sent in parallel to ensure thread safety.

     - By structuring the test cases this way, you'll have clear expectations for each scenario and can 
       better guarantee thorough test coverage.
     */
    func startPerformanceTest() {
        // identify user
        // identify(userID: "NX-11111")

        // delay for 3 seconds
        delay(4.0, closure: { [weak self] in
            guard let self else { return }

            // track user event
            self.track(eventName: "App Open")

            // track multi events to send them as one shout, should send them in one request as patch request
            for number in 1...20 {
                self.track(eventName: "Automatic event - \(number)")
            }

            // another delay for 1 second, send same event name, should ignore them
            delay(1) {
                for _ in 1...10 {
                    self.track(eventName: "Event 100000")
                }

                // another user event
                // self.userPilot.identify(userID: "NX-22222")

                // screen event
                self.screen("Main")

                // another delay for 2 seconds
                delay(2, closure: {
                    self.track(eventName: "Event - User payment")
                })

                // screen event
                self.screen("Profile")

                // another delay for 2 seconds
                delay(2) {
                    // screen event, same to previous screen, should be ignored
                    self.screen("Profile")

                    // screen event
                    self.screen("Main")
                }
            }

        })
    }

    /**
     Tests the sequence of identifying a user with different sets of attributes over time.
    
     This function simulates a series of updates to a user's identification information,
     with delays between each update to mimic asynchronous behavior or to observe changes over time.
     The `identify` function is called multiple times with different attributes and data,
     followed by a call to `userPilot.settings()` to log or review the final state of the user settings.
     
     The SDK should post identify event in case there is new data updated or added to user info,
     otherwise, is should be ignored
     */
    func testUpdateIdentifyUser() {
        identify(
            userID: "NX-33333",
            properties: [
                "age": 20,
                "name": "Motasem Hamed"
            ]
        )

        delay(4) { [weak self] in
            guard let self else { return }
            self.identify(
                userID: "NX-33333",
                properties: [
                    "salary": 4000,
                    "age": 25,
                    "name": "Motasem Hamed"
                ],
                company: [
                    "id": 100
                ]
            )

            delay(4) {
                self.identify(
                    userID: "NX-33333",
                    properties: [
                        "age": 30,
                        "isVerified": true,
                        "title": "Test",
                        "mail": [
                            "title": "mail@",
                            "domain": "gmail.com"
                        ]
                    ]
                )

                delay(4) {
                    self.identify(
                        userID: "NX-33333",
                        properties: [
                            "name": "Motasem Hamed"
                        ]
                    )

                    _ = self.userPilot?.settings()
                }
            }
        }
    }

}

// MARK: - UserPilotNavigationDelegate

extension UserPilotManager: UserPilotNavigationDelegate {

    func navigate(to url: URL, completion: @escaping (Bool) -> Void) {
        if url.scheme == "userpilot-example" {
            guard let destination = url.host else { return }
            if destination == "demo" {
                delay(0.4) {
                    FlowRoutingManager.shared.openViewController(DeepLinkViewController.newInstance())
                    completion(true)
                }
            }
        }
    }

}

// MARK: - UserPilotAnalyticsDelegate

extension UserPilotManager: UserPilotAnalyticsDelegate {

    func didTrack(analytic: UserPilotAnalytic, value: String, properties: [String: Any]?) {
        userPilotSDKEvents.insert(UserPilotSDKEvents(analytic: analytic, value: value, properties: properties), at: 0)
        if analytic == .identify {
            showIdentifyAlert()
        }
    }

    func showIdentifyAlert() {
        FlowRoutingManager.shared.showAlertMessage("User identify successfully!\nUser details:\n\(settings())")
    }
}

// MARK: - Hold SDK events

struct UserPilotSDKEvents {
    let analytic: UserPilotAnalytic
    let value: String
    let properties: [String: Any]?
}
