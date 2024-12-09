//
//  StorageManager.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 03/11/2024.
//

import Foundation

class StorageManager {

    // MARK: - Keys
    struct Keys {
        static let appToken = "APP_TOKEN"
    }

    static let shared = StorageManager()

    private init() {}

    // Save a value to UserDefaults
    func set<T>(value: T, forKey key: String) {
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }

    // Retrieve a value from UserDefaults
    func get<T>(forKey key: String) -> T? {
        return UserDefaults.standard.value(forKey: key) as? T
    }

    // Remove a value from UserDefaults
    func removeValue(forKey key: String) {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.synchronize()
    }

    // Check if a value exists in UserDefaults
    func hasValue(forKey key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) != nil
    }

    // Clear all stored data in UserDefaults
    func clearAll() {
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
    }
}
