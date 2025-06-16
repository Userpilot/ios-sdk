//
//  UserpilotManager.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 18/08/2024.
//

import Foundation
import Userpilot
import UIKit

class UserpilotManager {

    // MARK: - Public Properties

    static let shared = UserpilotManager()

    // MARK: - Private Properties

    /**
     We have made the Userpilot instance optional to allow flexibility in switching the token at runtime.
     However, this approach is not recommended because the token is intended to be configured only once.
     For better practice, declare the Userpilot instance inside init.
     */
    private var userpilot: Userpilot?

    private(set) var userpilotSDKEvents = [UserpilotSDKEvents]()

    // MARK: - Life Cycle

    private init() { }

    // MARK: - Userpilot SDK APIs

    func initialize() {
        guard
            let appToken: String = StorageManager.shared.get(forKey: StorageManager.Keys.appToken)
        else { return }
        userpilot = Userpilot(config: Userpilot.Config(token: appToken)
            .logging(enabled: true)
        )
        userpilot?.navigationDelegate = self
        userpilot?.analyticsDelegate = self
        userpilot?.experienceDelegate = self
    }

    /// Destroy Userpilot instance
    func destroy() {
        userpilot?.destroy()
        userpilot = nil
    }

    /// Userpilot Settings
    @discardableResult
    func settings() -> [String: Any] {
        return userpilot?.settings() ?? [:]
    }

    /// Identify user
    func identify(userId: String, properties: [String: Any]? = nil, company: [String: Any]? = nil) {
        userpilot?.identify(userId: userId, properties: properties, company: company)
    }

    /// login as Anonymous
    func anonymous() {
        userpilot?.anonymous()
    }

    /// Logout user
    func logout() {
        userpilot?.logout()
    }

    /// Track screens
    func screen(_ screenTitle: String) {
        userpilot?.screen(screenTitle)
    }

    /// Track user events
    func track(eventName: String, properties: [String: Any]? = nil) {
        userpilot?.track(eventName: eventName, properties: properties)
    }

    func triggerExperience(experienceId: String) {
        userpilot?.triggerExperience(experienceId)
    }

    func endExperience() {
        userpilot?.endExperience()
    }

    func setPushToken(deviceToken: Data) {
        userpilot?.setPushToken(deviceToken)
    }

    public func didReceiveNotification(response: UNNotificationResponse,
                                       completionHandler: @escaping () -> Void) -> Bool {
        return userpilot?.didReceiveNotification(response: response, completionHandler: completionHandler) ?? false
    }

}

// MARK: - UserpilotNavigationDelegate

extension UserpilotManager: UserpilotNavigationDelegate {

    func navigate(to url: URL) {
        delay(1) {
            if url.scheme == "userpilot-example" {
                guard let destination = url.host else {
                    return
                }
                if destination == "demo" {
                    FlowRoutingManager.shared.openViewController(DeepLinkViewController.newInstance())
                } else if destination == "identify" {
                    FlowRoutingManager.shared.openViewController(IdentifyViewController.newInstance())
                } else if destination == "screen_one" {
                    FlowRoutingManager.shared.openViewController(ScreenOneViewController.newInstance())
                } else if destination == "screen_two" {
                    FlowRoutingManager.shared.openViewController(ScreenTwoViewController.newInstance())
                }
            } else if url.scheme?.contains("http") == true || url.scheme?.contains("https") == true {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }

}

// MARK: - UserpilotAnalyticsDelegate

extension UserpilotManager: UserpilotAnalyticsDelegate {

    func didTrack(analytic: UserpilotAnalytic, value: String, properties: [String: Any]?) {
        userpilotSDKEvents.insert(UserpilotSDKEvents(analytic: analytic, value: value, properties: properties), at: 0)
        if analytic == .identify {
            showIdentifyAlert()
        }
    }

    func showIdentifyAlert() {
        if let topViewController =
            FlowRoutingManager.topMostController(),
           topViewController.isKind(of: IdentifyViewController.self) {
            (topViewController as? IdentifyViewController)?.onUserIdentified(settings())
        } else {
            FlowRoutingManager.shared.showAlertMessage(
                "User identify successfully!\nUser details:\n\(prettyPrint(settings()))")
        }
    }

    func prettyPrint(_ dictionary: [String: Any]) -> String {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        } else {
            return "\(dictionary)"
        }
    }
}

// MARK: - UserpilotAnalyticsDelegate

extension UserpilotManager: UserpilotExperienceDelegate {

    func onExperienceStateChanged(id: Int, state: UserpilotExperienceState) {
        print("Experience state -> \(state.rawValue), experienceId -> \(id)")
    }

    func onExperienceStepStateChanged(id: Int, state: UserpilotExperienceState,
                                      experienceId: Int, step: Int, totalSteps: Int) {
        print("Experience state -> step -> \(step), total steps -> \(totalSteps)")
    }

}

// MARK: - Hold SDK events

struct UserpilotSDKEvents {
    let analytic: UserpilotAnalytic
    let value: String
    let properties: [String: Any]?
}
