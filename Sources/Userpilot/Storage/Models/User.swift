//
//  User.swift
//  Userpilot SDK
//
//  Created by Userpilot on 15/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  The `User` struct is a holder for user details in the Userpilot SDK.
//  It tracks information about user properties and company attributes and supports
//  serialization for pending identify restoration.
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
