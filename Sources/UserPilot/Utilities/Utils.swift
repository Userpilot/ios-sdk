//
//  File.swift
//  
//
//  Created by Motasem Hamed on 10/10/2024.
//

import Foundation

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
func delay(_ delay: Double, closure: @escaping () -> Void) {

    DispatchQueue.main.asyncAfter(
        deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
        execute: closure)

}
