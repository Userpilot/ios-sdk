//
//  Utils.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 10/10/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
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

/// The size the backend asks an image to be, in points — **uncapped**.
///
/// Fitting it to the space that actually exists is ``UPImageView``'s job, and only it can do that
/// correctly: this function has no idea which container the image will end up in.
///
/// The cap used to live here, as `screenWidth - contentMargin * 2`. That silently assumed every host
/// was the carousel's full-bleed content area, and `SlideOutContainerView` puts the same image inside
/// a card that is itself inset from the screen edges — so the figure over-estimated the room there and
/// a wide image overflowed its card. Ported from the Android SDK, which made the same correction, so
/// both platforms resolve an image to the same size.
///
/// The backend expresses sizes in CSS px, mapped 1:1 onto points — deliberate, and what keeps an image
/// the same *physical* size across screen scales rather than shrinking as pixels get smaller.
///
/// **Behaviour by what the backend supplied:**
///
/// 1. **`style.width` and `style.height` both `"auto"`** — the image renders at its own `actual_size`.
///    It is never enlarged to fill its container; an image narrower than its host stays narrow and is
///    centred. This is the common case, and why a small image does not run edge to edge.
/// 2. **Both explicitly given** — that box is used verbatim.
/// 3. **Anything else** (either missing, or unparseable) — a square of `imageSize`.
///
/// - Parameter line: The line whose `attrs` carry `style` and `actual_size`.
/// - Returns: The requested width and height in points, before any fitting.
internal func getImageSize(for line: Line) -> CGSize {
    let defaultSize = ThemeHandler.DefaultValues.imageSize

    if line.attrs?.style?.width == "auto" && line.attrs?.style?.height == "auto" {
        let actualWidth = CGFloat(line.attrs?.actualSize?.width ?? Int(defaultSize))
        let actualHeight = CGFloat(line.attrs?.actualSize?.height ?? Int(defaultSize))
        return CGSize(width: actualWidth, height: actualHeight)
    }

    if let width = line.attrs?.style?.width?.toSize,
       let height = line.attrs?.style?.height?.toSize {
        return CGSize(width: width, height: height)
    }

    return CGSize(width: defaultSize, height: defaultSize)
}

/// Height ÷ width of the *source* image, used to recompute the height when a requested size has to be
/// shrunk to fit its container.
///
/// The source ratio rather than the requested box's, because that is the ratio the image is shrunk by —
/// including when the backend asked for a box of a different shape.
///
/// The guard matters: computing `actualHeight / actualWidth` directly makes an `actual_size` of
/// `{"width": 0}` a division by zero. Falls back to the requested box's own ratio, then to square.
internal func sourceAspect(for line: Line, imageSize: CGSize) -> CGFloat {
    let actualWidth = CGFloat(line.attrs?.actualSize?.width ?? 0)
    let actualHeight = CGFloat(line.attrs?.actualSize?.height ?? 0)

    if actualWidth > 0, actualHeight > 0 {
        return actualHeight / actualWidth
    }
    if imageSize.width > 0 {
        return imageSize.height / imageSize.width
    }
    return 1
}

/// Returns the width of the device's screen in points.
internal var screenWidth: CGFloat {
    return UIScreen.main.bounds.width
}

/// Returns the height of the device's screen in points.
internal var screenHeight: CGFloat {
    return UIScreen.main.bounds.height
}

/// Returns the multiplier used to adjust the width of UI elements based on screen size.
/// The multiplier is `0.9` for devices with a screen width of 800 points or less (typically phones),
/// and `0.8` for devices with a screen width greater than 800 points (typically tablets).
/// - Returns: A `CGFloat` representing the width multiplier.
internal var screenWidthMultiplier: CGFloat {
    return screenWidth <= 800 ? 0.9 : 0.8
}

/// Returns a Boolean value indicating whether the device is currently in landscape orientation.
/// - Returns: `true` if the device is in landscape mode
/// (either `.landscapeLeft` or `.landscapeRight`), `false` otherwise.
internal var isLandscape: Bool {
    return UIScreen.main.bounds.width > UIScreen.main.bounds.height
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
    guard let url = Userpilot.resourceBundle.url(forResource: fileName, withExtension: "json") else {
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        let decodedObject = try decoder.decode(T.self, from: data)
        return decodedObject
    } catch {
        return nil
    }
}

/// Retrieves the current key `UIWindow` in the app that is part of an active foreground scene.
/// - Returns: An optional `UIWindow`. Returns `nil` if no key window is found.
internal func getWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
        .filter({ $0.activationState == .foregroundActive })
        .compactMap({ $0 as? UIWindowScene })
        .first?.windows
        .filter({ $0.isKeyWindow }).first
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
///   - Includes only values of supported types: `String`, `Bool`, `Int`, `Int64`, `Double`, `Float`.
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
