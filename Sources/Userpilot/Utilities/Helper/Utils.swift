//
//  Utils.swift
//  Userpilot SDK
//
//  Created by Userpilot on 10/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  A Utils class for utilities functions.
//

import Foundation
import UIKit
import WebKit

// swiftlint:disable all
/**
 Generates a random number using a combination of two elements:
 
 1. `Double.random(in: 1..<10_000)`: Creates a random decimal number
 between 0 and 10,000, then scales it up to a value between 0 and 10,000.
 2. `(Date().timeIntervalSince1970 * Double.random(in: 1_000..<9_999))`: Multiplies the
 current time in seconds by another random number and a large scaling factor (100,000).
 
 The sum of the two values is then rounded down using `floor` and converted to `Int64`.
 */
internal func anonymousFactory() -> Int64 {
    let randomValue = floor(
        Double.random(in: 1.0..<10_000.0) +
        (Date().timeIntervalSince1970 * 1_000 * Double.random(in: 1_000.0..<9_999.0))
    )
    return Int64(randomValue)
}

/**
 Delays the execution of a closure by a specified amount of time.

 - Parameters:
 - delay: The time to delay the execution, in seconds.
 - closure: The closure to be executed after the delay.
 */
internal func delay(
    _ delay: Double,
    closure: @escaping () -> Void
) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
        execute: closure)
}

/// Returns the width of the device's screen in points.
internal var screenWidth: CGFloat {
    return UIScreen.main.bounds.width
}

/// Returns the multiplier used to adjust the width of UI elements based on screen size.
/// The multiplier is `0.9` for devices with a screen width of 800 points or less (typically phones),
/// and `0.8` for devices with a screen width greater than 800 points (typically tablets).
/// - Returns: A `CGFloat` representing the width multiplier.
internal var screenWidthMultiplier: CGFloat {
    return screenWidth <= 800 ? 0.9 : 0.8
}

/// Executes a block of code inside a `do-catch` block, catching and ignoring any errors or throwables.
///
/// This function wraps the execution of the provided `code` closure and silently handles any errors or throwables
/// that may occur during its execution. The error handling is done without taking any further action, essentially
/// ignoring any failures.
///
/// - Parameter code: The closure to execute. It is a block that takes no parameters and returns no result.
internal func tryCatch(code: () throws -> Void) {
    _ = try? code()
}

/// Executes a block of code inside a `do-catch` block, catching and returning a default value in case
///  of any error or throwable.
///
/// This function executes the provided `code` closure and returns its result if successful. In case of an error,
/// it returns a default value specified by the `defaultValue` parameter. If no `defaultValue` is provided,
/// it returns `nil`.
///
/// - Parameters:
///   - code: The closure to execute. It is a block that takes no parameters and returns a result of type `T`.
///   - defaultValue: An optional default value to return if an error is encountered. The default is `nil`.
/// - Returns: The result of executing `code` if successful, otherwise `defaultValue` or `nil` if no
/// default value is provided.
internal func tryCatch<T>(
    code: () throws -> T,
    defaultValue: T? = nil
) -> T? {
    do {
        return try code()
    } catch {
        return defaultValue
    }
}

/// Loads and decodes a JSON file from the app's resource bundle into a specified `Decodable` type.
/// - Parameters:
///   - fileName: The name of the JSON file (without the `.json` extension).
///   - type: The `Decodable` type to which the JSON content will be deserialized.
/// - Returns: An optional instance of the specified `Decodable` type `T`. Returns `nil`
/// if the file is not found or decoding fails.
internal func loadJSONFile<T: Decodable>(
    named fileName: String,
    as type: T.Type
) -> T? {
    return Userpilot.resourceBundle.loadJSONFile(named: fileName, as: type)
}

internal func print(
    _ items: Any...,
    separator: String = " ",
    terminator: String = "\n"
) {
    if Environment.environmentType == .DEVELOPMENT {
        let output = items.map { "\($0)" }.joined(separator: separator)
        Swift.print(output, terminator: terminator)
    }
}

/// Sanitizes a payload by filtering out unsupported property types and applying key transformations.
///
/// - Parameters:
///   - payload: The input dictionary (`Payload`) containing properties to be sanitized. Can be `nil`.
///   - payloadName: A string used in logging to identify the origin or purpose of the payload (e.g., `"properties"`, `"company"`).
///   - logger: An object conforming to the `Logging` protocol for emitting warnings about unsupported types.
///
/// - Returns: A sanitized `[String: Any]` dictionary:
///   - Keeps scalar strings, booleans and numbers; dictionaries, arrays and nulls are dropped.
///   - Returns `nil` if the sanitized result is empty.
internal func sanitizePayload(
    _ payload: Payload,
    payloadName: String,
    logger: Logging
) -> [String: Any]? {
    guard let payload = payload else { return nil }

    var sanitized: [String: Any] = [:]

    for (key, value) in payload {

        switch value {
        case is String, is Bool, is Int, is Int64, is Double, is Float, is NSNumber:
            sanitized[key] = value

        default:
            logger.error(
                "Dropped unsupported property in %@: \"%@\" has unsupported type %@. Allowed types: String, Bool, Int, Double, Float, or list of these types.",
                payloadName, key, String(describing: type(of: value))
            )
        }
    }

    return sanitized.isEmpty ? nil : sanitized
}

// swiftlint:enable all
