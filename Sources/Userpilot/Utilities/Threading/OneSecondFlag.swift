//
//  OneSecondFlag.kt
//  Userpilot SDK
//
//  Created by Motasem Hamed on 27/02/2025.
//  Copyright © 2024 Userpilot. All rights reserved.
//
//  [Brief Description]
//  Provides a boolean flag that becomes true for 1 second when activated,
//  and then automatically reverts to false.
//

import Foundation

internal class OneSecondFlag {

    private(set) var isActive: Bool = false

    private var workItem: DispatchWorkItem?

    func activate() {
        workItem?.cancel() // Cancel any ongoing activation
        isActive = true
        let workItem = DispatchWorkItem { [weak self] in
            self?.isActive = false
        }
        self.workItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }
}
