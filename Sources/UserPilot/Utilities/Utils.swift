//
//  Utils.swift
//  UserPilot SDK
//
//  Created by Motasem Hamed on 10/10/2024.
//  Copyright © 2024 UserPilot. All rights reserved.
//
//  [Brief Description]
//  A Utils class for utilities functions.
//

import Foundation
import UIKit

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
internal func delay(_ delay: Double, closure: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
        execute: closure)
}

/**
 * Image View Size Handling in SDK
 *
 * This function calculates the size of an image view dynamically based on the device type, screen dimensions,
 * and user-specified attributes. The goal is to ensure consistent rendering across various devices while
 * maintaining the original aspect ratio of the image.
 *
 * **Default Screen Width Calculation:**
 * - **Phones:** Default Screen Width = Device Screen Width × 0.8
 * - **Tablets:** Default Screen Width = Device Screen Width × 0.6
 *
 * **Behavior Based on User-Specified Dimensions:**
 *
 * 1. **When User Specifies "Auto" for Width and Height:**
 *    - Case 1: If the actual image width is less than or equal to the default screen width:
 *      - The image size is set to the actual width and height of the image.
 *    - Case 2: If the actual image width is greater than the default screen width:
 *      - The image width is set to the default screen width.
 *      - The image height is calculated to maintain the original aspect ratio using the formula:
 *        `New Image Height = (Actual Image Height / Actual Image Width) * Default Screen Width`
 *
 * 2. **When User Specifies Both Width and Height:**
 *    - Case 1: If the specified width is less than or equal to the default screen width:
 *      - The image size is directly set to the user-provided width and height.
 *    - Case 2: If the specified width is greater than the default screen width:
 *      - The image width is set to the default screen width.
 *      - The image height is recalculated using the same aspect ratio formula as above:
 *        `New Image Height = (Actual Image Height / Actual Image Width) * Default Screen Width`
 *
 * 3. **Fallback Behavior:**
 *    - If no specific size is provided (width or height is missing or `nil`), the image size defaults
 *      to a preconfigured value defined as `defaultSize`.
 *
 * @param actualWidth The actual width of the image provided by the user or derived from the image itself.
 * @param actualHeight The actual height of the image provided by the user or derived from the image itself.
 * @param screenWidth The calculated screen width based on the device type (phone or tablet).
 * @return A `CGSize` representing the calculated width and height of the image.
 */
internal func getImageSize(for line: Line) -> CGSize {
    let defaultSize = ThemeHandler.DefaultValues.imageSize
    let actualWidth = CGFloat(line.attrs?.actualSize?.width ?? Int(defaultSize))
    let actualHeight = CGFloat(line.attrs?.actualSize?.height ?? Int(defaultSize))
    let screenWidth = screenWidth() * screenWidthMultiplier()

    if line.attrs?.style?.width == "auto" && line.attrs?.style?.height == "auto" {
        if actualWidth > screenWidth {
            let newHeight = (screenWidth * actualHeight) / actualWidth
            return CGSize(width: screenWidth, height: newHeight)
        } else {
            return CGSize(width: actualWidth, height: actualHeight)
        }
    } else {
        if let width = line.attrs?.style?.width?.toSize,
           let height = line.attrs?.style?.height?.toSize {
            if width > screenWidth {
                let newHeight = (screenWidth * actualHeight) / actualWidth
                return CGSize(width: screenWidth, height: newHeight)
            } else {
                return CGSize(width: width, height: height)
            }
        } else {
            return CGSize(width: defaultSize, height: defaultSize)
        }
    }
}

internal func screenWidthMultiplier() -> CGFloat {
    if screenWidth() <= 800 { // Phone (width <= 800px)
        return CGFloat(0.9)
    } else { // Tablet (width > 800px)
        return CGFloat(0.8)
    }
}

internal func screenWidth() -> CGFloat {
    return UIScreen.main.bounds.width
}
