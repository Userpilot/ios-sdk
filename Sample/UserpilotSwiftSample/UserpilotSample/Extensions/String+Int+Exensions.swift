//
//  String+Exensions.swift
//  UserpilotSample
//
//  Created by Motasem Hamed on 11/08/2024.
//

import Foundation
import UIKit

internal extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

internal extension Int {
    /// Loops from 0 to (self - 1) and executes the closure with the current index
    func loop(_ action: (Int) -> Void) {
        guard self > 0 else { return }
        for index in 0..<self {
            action(index)
        }
    }
}
