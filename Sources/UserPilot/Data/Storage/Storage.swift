//
//  Storage.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 18/08/2024.
//  Copyright © 2021 UserPilot. All rights reserved.
//
// [Brief Description]
// Storage to hold/cache runtime data
//

import Foundation
import UIKit

protocol DataStoring: AnyObject {
    /// The socket URL. A value for socket URL.
    var socketURL: String { get set }

    /// The device ID. A value generated once upon first initialization of the SDK after installation.
    var deviceID: String { get set }

    /// The current user ID. Can be a generated anonymous value, or authenticated value provided by application.
    var userID: String { get set }

    /// Tracks whether the current user has been identified explicitly as
    /// an anonymous user, as opposed to an identified user.
    var isAnonymous: Bool { get set }
}

class Storage: DataStoring {

    // MARK: - Keys
    private enum Key: String {
        case socketURL
        case deviceID
        case userID
        case isAnonymous
    }

    // MARK: - Properties
    private let config: UserPilot.Config

    private lazy var defaults = UserDefaults(
        suiteName: "\(UserDefaultConstants.USER_DEFAULT_SUITE_NAME)\(Bundle.main.identifier)"
    )

    var socketURL: String {
        get {
            return read(.socketURL, defaultValue: "")
        }
        set {
            write(.socketURL, newValue: newValue)
        }
    }

    var deviceID: String {
        get {
            return read(.deviceID, defaultValue: "")
        }
        set {
            write(.deviceID, newValue: newValue)
        }
    }

    var userID: String {
        get {
            return read(.userID, defaultValue: "")
        }
        set {
            write(.userID, newValue: newValue)
        }
    }

    var isAnonymous: Bool {
        get {
            return read(.isAnonymous, defaultValue: true)
        }
        set {
            write(.isAnonymous, newValue: newValue)
        }
    }

    // MARK: - init
    init(container: DIContainer) {
        self.config = container.resolve(UserPilot.Config.self)
        self.deviceID = UIDevice.identifier
    }

    // MARK: - Helper methods
    private func read<T>(_ key: Key, defaultValue: T) -> T {
        return defaults?.object(forKey: key.rawValue) as? T ?? defaultValue
    }

    private func write<T>(_ key: Key, newValue: T?) {
        guard let newValue = newValue else {
            defaults?.removeObject(forKey: key.rawValue)
            return
        }

        defaults?.set(newValue, forKey: key.rawValue)
    }
}
