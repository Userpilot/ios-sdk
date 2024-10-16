//
//  User.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 15/09/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  The `User` struct is a holder for user details in the UserPilot SDK.
//  It tracks information about user properties and company attributes and supports
//  custom serialization, updating with events, and comparison between user objects.
//

import Foundation
import UIKit

/**
 * The `User` struct represents a user in the UserPilot SDK.
 * It stores user-specific details such as the user ID, user properties, and company attributes.
 *
 * Properties:
 * - `userID`: The unique identifier of the user.
 * - `properties`: A dictionary that holds various user properties as key-value pairs.
 * - `company`: A dictionary that holds various company-related data as key-value pairs.
 */
internal struct User {
    var userID: String
    var properties: [String: Any]
    var company: [String: Any]

    init(userID: String = "", properties: [String: Any] = [:], company: [String: Any] = [:]) {
        self.userID = userID
        self.properties = properties
        self.company = company
    }
}

/**
 * Extension of the `User` struct to conform to `CustomStringConvertible` for custom string representations.
 * This allows for a human-readable format when printing user details, such as in debugging or logging.
 *
 * The custom `description` property provides a formatted string that includes the userID, properties, and company data.
 */
extension User: CustomStringConvertible {
    var description: String {
        let propertiesDescription = properties.map { "\($0): \($1)" }.joined(separator: ", ")
        let companyDescription = company.map { "\($0): \($1)" }.joined(separator: ", ")

        return """
        User:
        - userID: \(userID)
        - properties: \(propertiesDescription)
        - company: \(companyDescription)
        """
    }
}

// MARK: - JSON formater

extension User {

    func toJson() -> String? {
        var dict: [String: Any] = [:]
        dict["userID"] = userID
        dict["properties"] = properties
        dict["company"] = company
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict, options: .withoutEscapingSlashes) {
            // swiftlint:disable:next non_optional_string_data_conversion
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }

    static func fromJson(_ jsonString: String) -> User {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return User()
        }
        if let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
            if let userID = jsonDict["userID"] as? String,
                let properties = jsonDict["properties"] as? [String: Any],
                let company = jsonDict["company"] as? [String: Any] {
                return User(userID: userID, properties: properties, company: company)
            }
        }
        return User()
    }
}

extension User {

    /**
     * Updates the current `User` object with the data from the given `Event`.
     * If the `userID` in the event differs from the current user's `userID`, the user data is reset.
     * It then merges the new properties and company information from the event into the current user.
     *
     * @param event The event containing user-related data such as userID, properties, and company information.
     * @return The updated `User` object with the new data.
     */
    mutating func updateUser(event: Event) -> User {
        guard let eventUserID = event.userID else { return self }

        if userID != eventUserID {
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

        userID = eventUserID
        return self
    }

    /**
     * Compares the current `User` object to the data from an `Event` to determine if they represent the same user.
     * The comparison checks the `userID`, user properties, and company data for equality.
     *
     * @param event The event to compare against the current user.
     * @return `true` if the event data matches the current user, otherwise `false`.
     */
    func isSameIdentifyEvent(event: Event) -> Bool {
        guard userID == event.type.userID else {
            return false
        }
        let isMetaDataMapSame = (properties).isEqual(to: event.properties ?? [:])
        let isCompanyDataMapSame = (company).isEqual(to: event.company ?? [:])
        return isMetaDataMapSame && isCompanyDataMapSame
    }
}

/**
 * Extension for `Dictionary` where the key is a `String` and the value is `Any`.
 * Adds the ability to deeply compare dictionaries to determine if they are equal.
 */
extension Dictionary where Key == String, Value == Any {

    /**
     * Compares the current dictionary to another dictionary.
     * The comparison checks that all keys and values match, including performing deep comparison of nested structures.
     *
     * @param other The other dictionary to compare against.
     * @return `true` if both dictionaries are identical in terms of keys and values, otherwise `false`.
     */
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

            // Compare values using a helper function for deep comparison
            if !compareValues(value, otherValue) {
                return false
            }
        }

        return true
    }

    // Helper function to deeply compare Any type values
    private func compareValues(_ lhs: Any, _ rhs: Any) -> Bool {
        switch (lhs, rhs) {
        case (let left as Int, let right as Int):
            return left == right
        case (let left as String, let right as String):
            return left == right
        case (let left as Double, let right as Double):
            return left == right
        case (let left as Bool, let right as Bool):
            return left == right
        case (let left as [String: Any], let right as [String: Any]):
            return left.isEqual(to: right)  // Recursively compare dictionaries
        case (let left as [Any], let right as [Any]):
            return compareArrays(left, right)  // Compare arrays recursively
        default:
            return false  // If types or values do not match, return false
        }
    }

    // Helper function to compare arrays of Any
    private func compareArrays(_ lhs: [Any], _ rhs: [Any]) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }

        for (index, leftValue) in lhs.enumerated() {
            let rightValue = rhs[index]
            if !compareValues(leftValue, rightValue) {
                return false
            }
        }

        return true
    }
}

/**
 * Extension of the `User` struct to conform to `Encodable`.
 * Allows the user object to be serialized into JSON, supporting dynamic keys for user properties and company data.
 */
extension User: Encodable {
    enum CodingKeys: CodingKey {
        case userID
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
        try container.encode(userID, forKey: .userID)

        var propertiesAttributesContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self,
                                                                      forKey: .properties)
        try propertiesAttributesContainer.encodeSkippingInvalid(properties)

        var companyAttributesContainer = container.nestedContainer(keyedBy: DynamicCodingKeys.self,
                                                                   forKey: .company)
        try companyAttributesContainer.encodeSkippingInvalid(company)
    }
}

/// Extension function to deserialize a `String` into a `User` object
extension String {

    func toUser() -> User {
        return  User.fromJson(self)
    }

}
