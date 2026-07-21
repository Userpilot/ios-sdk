//
//  UserpilotManager.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 18/08/2024.
//

import Foundation
import Userpilot
import UIKit

// swiftlint:disable all

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
    
    private(set) var userpilotSDKEvents = [UserpilotSDKEvent]()
    
    // MARK: - Life Cycle
    
    private init() { }
    
    // MARK: - Userpilot SDK APIs
    
    func initialize() {
        guard let appToken: String = StorageManager.shared.get(forKey: StorageManager.Keys.appToken) else { return }
        userpilot = Userpilot(config: Userpilot.Config(token: appToken)
            .logging(enabled: ConfigFlag.loggingEnabled.value)
            .enableUseInAppBrowser(ConfigFlag.useInAppBrowser.value)
            .allowReceiveEventsFromExternalSource(ConfigFlag.allowReceiveEventsFromExternalSource.value)
            .disableRequestPushNotificationsPermission(
                ConfigFlag.disableRequestPushNotificationsPermission.value)
            .enableScreenAutoCapture(ConfigFlag.enableScreenAutoCapture.value)
            .enableInteractionAutoCapture(ConfigFlag.enableInteractionAutoCapture.value)
            .enableInteractionTextCapture(ConfigFlag.enableInteractionTextCapture.value)
            .enableInteractionAccessibilityLabelCapture(
                ConfigFlag.enableInteractionAccessibilityLabelCapture.value)
            .enableInteractionValueCapture(ConfigFlag.enableInteractionValueCapture.value)
        )
        userpilot?.navigationDelegate = self
        userpilot?.analyticsDelegate = self
        userpilot?.experienceDelegate = self
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

    /// Pauses automatic capture for this instance until `resumeAutoCapture()` is called.
    func stopAutoCapture() {
        userpilot?.stopAutoCapture()
    }

    /// Resumes automatic capture for this instance after `stopAutoCapture()`.
    func resumeAutoCapture() {
        userpilot?.resumeAutoCapture()
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
    
    public func didReceiveNotification(
        response: UNNotificationResponse,
        completionHandler: @escaping () -> Void
    ) -> Bool {
        return userpilot?.didReceiveNotification(response: response, completionHandler: completionHandler) ?? false
    }
    
}

// MARK: - UserpilotNavigationDelegate

extension UserpilotManager: UserpilotNavigationDelegate {
    
    func navigate(to url: URL) {
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

// MARK: - UserpilotAnalyticsDelegate

extension UserpilotManager: UserpilotAnalyticsDelegate {
    
    func didTrack(analytic: UserpilotAnalytic, value: String, properties: [String: Any]?) {
        userpilotSDKEvents.insert(
            UserpilotSDKEvent(
                analytic: analytic.rawValueString,
                value: value,
                properties: properties
            ),
            at: 0
        )
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
    
    func onExperienceStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber?,
        experienceState: UserpilotExperienceState
    ) {
        userpilotSDKEvents.insert(
            UserpilotSDKEvent(
                analytic: "Experience \(experienceType.stringValue) State Changed",
                value: "Experience ID: \(experienceId?.intValue ?? 0) - State: \(experienceState.stringValue)",
                properties: nil
            ),
            at: 0
        )
    }
    
    func onExperienceStepStateChanged(
        experienceType: UserpilotExperienceType,
        experienceId: NSNumber,
        stepId: NSNumber,
        stepState: UserpilotExperienceState,
        step: NSNumber?,
        totalSteps: NSNumber?
    ) {
        userpilotSDKEvents.insert(
            UserpilotSDKEvent(
                analytic: "Experience \(experienceType.stringValue) State Changed",
                value: "step ID: \(stepId) - State: $stepId \(stepState.stringValue)",
                properties: nil
            ),
            at: 0
        )
    }
}

// MARK: - Hold SDK events

struct UserpilotSDKEvent {
    let analytic: String
    let value: String
    let properties: [String: Any]?
}


public extension UserpilotExperienceType {
    var stringValue: String {
        switch self {
        case .flow: return "flow"
        case .survey: return "survey"
        case .nps: return "nps"
        }
    }
}

public extension UserpilotExperienceState {
    var stringValue: String {
        switch self {
        case .started: return "started"
        case .completed: return "completed"
        case .dismissed: return "dismissed"
        case .skipped: return "skipped"
        case .submitted: return "submitted"
        }
    }
}

// swiftlint:enable all
