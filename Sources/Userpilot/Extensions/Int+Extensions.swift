//
//  Int+Extension.swift
//  Userpilot SDK
//
//  Created by Motasem Hamed on 04/09/2024.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  `Int+Extension` contains an extension with helper methods for the `Int` class.
//  This extension provides additional functionality to modify integer values easily.
//

import Foundation
import UIKit

internal extension Int {
    mutating func increment(by value: Int = 1) {
        self += value
    }

    func toString() -> String {
        return String(self)
    }
}

internal extension CGFloat {
    var negative: CGFloat {
        return -self
    }
}

internal extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

internal extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
