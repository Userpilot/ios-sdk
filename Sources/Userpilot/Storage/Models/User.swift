//
//  User.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 15/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  The `User` struct is a holder for user details in the Userpilot SDK.
//  It tracks information about user properties and company attributes and supports
//  custom serialization, updating with events, and comparison between user objects.
//

import Foundation
import UIKit

/**
 * The `User` struct represents a user in the Userpilot SDK.
 * It stores user-specific details such as the user ID, user properties, and company attributes.
 *
 * Properties:
 * - `userId`: The unique identifier of the user.
 * - `properties`: A dictionary that holds various user properties as key-value pairs.
 * - `company`: A dictionary that holds various company-related data as key-value pairs.
 */
internal struct User {
    var userId: String
    var properties: [String: Any]
    var company: [String: Any]

    init(userId: String = "", properties: [String: Any] = [:], company: [String: Any] = [:]) {
        self.userId = userId
        self.properties = properties
        self.company = company
    }
}

/**
 * Extension of the `User` struct to conform to `CustomStringConvertible` for custom string representations.
 * This allows for a human-readable format when printing user details, such as in debugging or logging.
 *
 * The custom `description` property provides a formatted string that includes the userId, properties, and company data.
 */
extension User: CustomStringConvertible {
    var description: String {
        let propertiesDescription = properties.map { "\($0): \($1)" }.joined(separator: ", ")
        let companyDescription = company.map { "\($0): \($1)" }.joined(separator: ", ")

        return """
        User:
        - userId: \(userId)
        - properties: \(propertiesDescription)
        - company: \(companyDescription)
        """
    }
}

// MARK: - JSON formater

extension User {
    func toJson() -> String? {
        var dict: [String: Any] = [:]
        dict["userId"] = userId
        dict["properties"] = properties
        dict["company"] = company
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .withoutEscapingSlashes) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }

    static func fromJson(_ jsonString: String) -> User {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return User()
        }
        if let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            if let userId = jsonDict["userId"] as? String,
               let properties = jsonDict["properties"] as? [String: Any],
               let company = jsonDict["company"] as? [String: Any] {
                return User(userId: userId, properties: properties, company: company)
            }
        }
        return User()
    }
}

extension User {

    /**
     * Updates the current `User` object with the data from the given `Event`.
     * If the `userId` in the event differs from the current user's `userId`, the user data is reset.
     * It then merges the new properties and company information from the event into the current user.
     *
     * @param event The event containing user-related data such as userId, properties, and company information.
     * @return The updated `User` object with the new data.
     */
    mutating func updateUser(event: Event) -> User {
        guard let eventUserId = event.userId else { return self }

        if userId != eventUserId {
            self = User()
        }

        // Assuming properties and company are dictionaries with property list-compatible values
        if let eventProperties = event.properties {
            // Convert eventProperties to a dictionary with compatible values if needed
            properties.merge(eventProperties) { (_, new) in new }
        }

        if let eventCompany = event.company {
            // Convert eventCompany to a dictionary with compatible values if needed
            company.merge(eventCompany) { (_, new) in new }
        }

        userId = eventUserId
        return self
    }

    /// Compares this User with an Event to determine if they represent the same identify event
    /// - Parameter event: The Event to compare against
    /// - Returns: true if the user and event represent the same identify event
    func isSameIdentifyEvent(event: Event) -> Bool {
        // Fix: Compare userId with event.userId, not event.type.userId
        guard userId == event.userId else {
            return false
        }

        // For partial updates, check if the event is a subset of existing user data
        let eventProperties = event.properties ?? [:]
        let eventCompany = event.company ?? [:]

        // If event has no properties/company data, consider it the same user (just userId match)
        if eventProperties.isEmpty && eventCompany.isEmpty {
            return true
        }

        // Check if event properties are a subset of user properties with same values
        let propertiesMatch = properties.containsAll(from: eventProperties)
        let companyDataMatch = company.containsAll(from: eventCompany)

        return propertiesMatch && companyDataMatch
    }

    /// Alternative method with different comparison strategies
    func isSameIdentifyEvent(event: Event, strategy: ComparisonStrategy = .partialUpdate) -> Bool {
        guard userId == event.userId else {
            return false
        }

        let eventProperties = event.properties ?? [:]
        let eventCompany = event.company ?? [:]

        switch strategy {
        case .exactMatch:
            // Original behavior - exact match required
            return properties.isEqual(to: eventProperties) &&
            company.isEqual(to: eventCompany)

        case .partialUpdate:
            // New behavior - event can be subset of stored user
            return properties.containsAll(from: eventProperties) &&
            company.containsAll(from: eventCompany)

        case .ignoreEmpty:
            // Ignore empty properties in comparison
            let filteredProperties = properties.filteringOutEmptyValues()
            let filteredEventProperties = eventProperties.filteringOutEmptyValues()
            let filteredCompany = company.filteringOutEmptyValues()
            let filteredEventCompany = eventCompany.filteringOutEmptyValues()

            return filteredProperties.containsAll(from: filteredEventProperties) &&
            filteredCompany.containsAll(from: filteredEventCompany)
        }
    }
}

enum ComparisonStrategy {
    case exactMatch      // Both objects must be identical
    case partialUpdate   // Event can be a subset of stored user
    case ignoreEmpty     // Ignore empty values in comparison
}

/**
 * Extension for `Dictionary` where the key is a `String` and the value is `Any`.
 * Adds the ability to deeply compare dictionaries to determine if they are equal.
 */
internal extension Dictionary where Key == String, Value == Any {

    /// Compares the current dictionary to another dictionary with deep comparison
    /// - Parameter other: The other dictionary to compare against
    /// - Returns: true if both dictionaries are identical in terms of keys and values
    func isEqual(to other: [String: Any]) -> Bool {
        // Check if both dictionaries have the same size
        guard self.count == other.count else {
            return false
        }

        // Check if all keys and values match
        for (key, value) in self {
            guard let otherValue = other[key] else {
                return false
            }

            if !compareValues(value, otherValue) {
                return false
            }
        }

        return true
    }

    /// Filters out empty values (empty strings, empty arrays, empty dictionaries)
    /// - Returns: A new dictionary with empty values removed
    func filteringOutEmptyValues() -> [String: Any] {
        return self.compactMapValues { value in
            switch value {
            case let string as String:
                return string.isEmpty ? nil : value
            case let array as [Any]:
                return array.isEmpty ? nil : value
            case let dict as [String: Any]:
                return dict.isEmpty ? nil : value
            default:
                return value
            }
        }
    }

    /// Checks if this dictionary contains all key-value pairs from another dictionary
    /// This enables partial update detection - the other dictionary can be a subset
    /// - Parameter other: The dictionary to check against (can be partial)
    /// - Returns: true if all key-value pairs in 'other' exist in this dictionary with same values
    func containsAll(from other: [String: Any]) -> Bool {
        // Empty dictionary is considered contained in any dictionary
        guard !other.isEmpty else {
            return true
        }

        // Check if all key-value pairs in 'other' exist in self with same values
        for (key, otherValue) in other {
            guard let selfValue = self[key] else {
                return false // Key doesn't exist in self
            }

            if !compareValues(selfValue, otherValue) {
                return false // Values don't match
            }
        }

        return true
    }

    // MARK: - Private Helper Methods

    // Deeply compares Any type values with improved type handling
    // swiftlint:disable:next cyclomatic_complexity
    private func compareValues(_ lhs: Any, _ rhs: Any) -> Bool {
        // Handle nil values
        if isNil(lhs) && isNil(rhs) {
            return true
        }
        if isNil(lhs) || isNil(rhs) {
            return false
        }

        switch (lhs, rhs) {
        case (let left as Int, let right as Int):
            return left == right
        case (let left as String, let right as String):
            return left == right
        case (let left as Double, let right as Double):
            return left.isEqual(to: right, tolerance: 0.0001) // Handle floating point precision
        case (let left as Float, let right as Float):
            return abs(left - right) < 0.0001
        case (let left as Bool, let right as Bool):
            return left == right
        case (let left as [String: Any], let right as [String: Any]):
            return left.isEqual(to: right)
        case (let left as [Any], let right as [Any]):
            return compareArrays(left, right)
            // Handle number type conversions
        case (let left as Int, let right as Double):
            return Double(left) == right
        case (let left as Double, let right as Int):
            return left == Double(right)
        case (let left as NSNumber, let right as NSNumber):
            return left.isEqual(to: right)
        default:
            // Fallback to NSObject comparison for other types
            if let leftObj = lhs as? NSObject, let rightObj = rhs as? NSObject {
                return leftObj.isEqual(rightObj)
            }
            return false
        }
    }

    /// Compares arrays of Any with deep comparison
    private func compareArrays(_ lhs: [Any], _ rhs: [Any]) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        for (leftValue, rightValue) in zip(lhs, rhs) {
            // swiftlint:disable:next for_where
            if !compareValues(leftValue, rightValue) {
                return false
            }
        }

        return true
    }

    /// Helper to check if a value is nil (including NSNull)
    private func isNil(_ value: Any) -> Bool {
        if value is NSNull {
            return true
        }
        // Use reflection to check for nil optionals
        let mirror = Mirror(reflecting: value)
        return mirror.displayStyle == .optional && mirror.children.count == 0
    }
}

// MARK: - Double Extension for Floating Point Comparison

private extension Double {
    func isEqual(to other: Double, tolerance: Double) -> Bool {
        return abs(self - other) <= tolerance
    }
}

/**
 * Extension of the `User` struct to conform to `Encodable`.
 * Allows the user object to be serialized into JSON, supporting dynamic keys for user properties and company data.
 */
extension User: Encodable {
    enum CodingKeys: CodingKey {
        case userId
        case properties
        case company
    }

    /**
     * Encodes the user object into JSON format.
     *
     * - User ID is encoded as a standard key.
     * - User properties and company data are encoded as nested containers with dynamic keys.
     *
     * @param encoder The encoder used to serialize the user object.
     */
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)

        var propertiesAttributesContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self,
                                                                      forKey: .properties)
        try propertiesAttributesContainer.encodeSkippingInvalid(properties)

        var companyAttributesContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self,
                                                                   forKey: .company)
        try companyAttributesContainer.encodeSkippingInvalid(company)
    }
}

/// Extension function to deserialize a `String` into a `User` object
internal extension String {

    func toUser() -> User {
        return  User.fromJson(self)
    }
}
