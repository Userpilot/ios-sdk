//
//  UserpilotManager.swift
//  UserpilotSwiftUISample
//
//  Created by Motasem Hamed on 11/01/2026.
//

import Userpilot

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
    
    
    // MARK: - Life Cycle
    
    private init() { }
    
    // MARK: - Userpilot SDK APIs
    
    func initialize() {
        userpilot = Userpilot(config: Userpilot.Config(token: "NX-b83a34b8")
            .logging(enabled: true)
            .enableUseInAppBrowser()
            .enableScreenAutoCapture()
            .enableInteractionAutoCapture()
            .appFramework(.SwiftUI)
        )
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
    
    /// Track screens (manual). When `enableScreenAutoCapture` is on, the SDK ignores manual `screen` calls.
    func screen(_ screenTitle: String) {
        userpilot?.screen(screenTitle)
    }

    /// Track user events
    func track(eventName: String, properties: [String: Any]? = nil) {
        userpilot?.track(eventName: eventName, properties: properties)
    }
    
    func triggerExperience(experienceId: String) {
        //userpilot?.triggerExperience(experienceId)
    }
    
}
